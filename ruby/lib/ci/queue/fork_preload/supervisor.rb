# frozen_string_literal: true

module CI
  module Queue
    module ForkPreload
      # Parent-side lifecycle: quiesce, compact, fork, forward signals, reap, report.
      # Never touches the queue and never runs a test.
      class Supervisor
        def initialize(worker_count: ForkPreload.worker_count)
          @worker_count = worker_count
          @children = {}
        end

        def run(&run_worker)
          quiesce_shared_state
          compact_heap_for_sharing
          fork_workers(run_worker)
          ForkPreload.after_fork_in_parent_hooks.each(&:call)
          forward_signals_to_children
          reap_all == @worker_count ? 0 : 1
        end

        private

        def quiesce_shared_state
          ForkPreload.before_fork_hooks.each(&:call)
          $stdout.flush
          $stderr.flush
        end

        # Compaction packs objects densely so more is shared at the fork. The trade is that a
        # page then holds objects from many sources, so one write privatises all of them.
        # Off is an experiment, not a default.
        def compact_heap_for_sharing
          return unless ENV.fetch('CI_QUEUE_FORK_COMPACT', '1') == '1'

          Process.warmup if Process.respond_to?(:warmup)
        end

        def fork_workers(run_worker)
          warn "[fork-preload] parent #{Process.pid}: forking #{@worker_count} workers"
          (1..@worker_count).each do |number|
            started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            pid = WorkerProcess.fork(number: number, &run_worker)
            @children[pid] = [number, started]
          end
        end

        def forward_signals_to_children
          %w[INT TERM].each do |signal|
            trap(signal) do
              @children.each_key do |pid|
                Process.kill(signal, pid)
              rescue Errno::ESRCH
                nil
              end
            end
          end
        end

        def reap_all
          reaped = 0
          TimesReport.open do |report|
            until @children.empty?
              pid, status = Process.wait2
              number, started = @children.delete(pid)
              next unless number

              seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round
              report.record(worker: number, seconds: seconds, exit_code: exit_code_of(status))
              reaped += 1
            end
          rescue Errno::ECHILD
            warn "[fork-preload] ran out of children with #{@children.size} unreaped"
          end
          reaped
        end

        # Normalise a signal death the way a shell does, so a crash detector keyed on exit
        # codes still fires.
        def exit_code_of(status)
          return status.exitstatus if status.exitstatus
          return 128 + status.termsig if status.termsig

          1
        end
      end
    end
  end
end
