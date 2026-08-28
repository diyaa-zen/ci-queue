# frozen_string_literal: true

module CI
  module Queue
    module ForkPreload
      module Rebindings
        class << self
          def install
            ForkPreload.after_fork { |number| redirect_standard_streams(number) }
            ForkPreload.after_fork { |number| publish_worker_number(number) }
            ForkPreload.after_fork { |number| retake_coverage(number) }
            ForkPreload.after_fork { |_number| reseed_random }
          end

          # Worker 1 takes a blank value, matching the numbering that per-worker database
          # names interpolate.
          def worker_env_value(number)
            number == 1 ? '' : number.to_s
          end

          private

          def redirect_standard_streams(number)
            FileUtils.mkdir_p(ForkPreload.log_dir)
            $stdout.reopen(::File.join(ForkPreload.log_dir, "worker_#{number}.log"), 'w')
            $stderr.reopen(::File.join(ForkPreload.log_dir, "worker_#{number}.err"), 'w')
            $stdout.sync = true
            $stderr.sync = true
          end

          def publish_worker_number(number)
            ENV[ForkPreload.worker_env_var] = worker_env_value(number)
          end

          # SimpleCov skips its at_exit in any process whose pid differs from the one that
          # called start. The directory name is the one ci-queue's collate step globs for.
          def retake_coverage(number)
            return unless defined?(SimpleCov)

            SimpleCov.pid = Process.pid
            SimpleCov.coverage_dir "coverage/ci_queue_worker_#{number}"
            SimpleCov.command_name "simplecov#{worker_env_value(number)}"
          end

          def reseed_random
            srand(Random.new_seed)
          end
        end
      end
    end
  end
end
