# frozen_string_literal: true

require 'ci/queue'
require 'ci/queue/fork_preload/times_report'
require 'ci/queue/fork_preload/worker_process'
require 'ci/queue/fork_preload/supervisor'

module CI
  module Queue
    # Boot once, fork the workers. Each worker otherwise pays the whole boot again, and the
    # pages they would have shared are instead copied N times.
    #
    # The mechanism is here; what has to be quiesced before the fork and rebound after it is
    # application knowledge, so it comes in through the hooks below rather than being guessed.
    module ForkPreload
      class << self
        attr_writer :times_report_path

        def enabled?
          ENV['CI_QUEUE_FORK_PRELOAD'] == '1'
        end

        def worker_count
          Integer(ENV.fetch('CI_QUEUE_FORK_WORKERS', '1'))
        end

        def times_report_path
          @times_report_path ||= 'log/ci_queue/worker_times.txt'
        end

        # Runs in the parent, before the fork: close what must not be shared across it.
        def before_fork(&block)
          before_fork_hooks << block
        end

        # Runs in each child, before it takes any work. Yielded the worker number.
        def after_fork(&block)
          after_fork_hooks << block
        end

        # Runs in the parent once the children exist. The parent accumulated boot state that
        # the children now own copies of; anything it must not also write belongs here.
        def after_fork_in_parent(&block)
          after_fork_in_parent_hooks << block
        end

        def before_fork_hooks
          @before_fork_hooks ||= []
        end

        def after_fork_hooks
          @after_fork_hooks ||= []
        end

        def after_fork_in_parent_hooks
          @after_fork_in_parent_hooks ||= []
        end
      end
    end
  end
end
