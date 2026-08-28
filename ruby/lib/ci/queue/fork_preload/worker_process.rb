# frozen_string_literal: true

module CI
  module Queue
    module ForkPreload
      class WorkerProcess
        def self.fork(number:, &run_worker)
          Process.fork { new(number).run(&run_worker) }
        end

        def initialize(number)
          @number = number
        end

        def run
          ForkPreload.after_fork_hooks.each { |hook| hook.call(@number) }
          code = yield
          warn "[fork-preload] worker #{@number} finished with #{code}"
          exit code
        end
      end
    end
  end
end
