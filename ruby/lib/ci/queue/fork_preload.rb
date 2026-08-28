# frozen_string_literal: true

require 'fileutils'
require 'ci/queue'
require 'ci/queue/fork_preload/times_report'
require 'ci/queue/fork_preload/worker_process'
require 'ci/queue/fork_preload/supervisor'
require 'ci/queue/fork_preload/rebindings'

module CI
  module Queue
    module ForkPreload
      class << self
        attr_writer :times_report_path, :log_dir, :worker_env_var

        def enabled?
          ENV['CI_QUEUE_FORK_PRELOAD'] == '1'
        end

        def worker_count
          Integer(ENV.fetch('CI_QUEUE_FORK_WORKERS', '1'))
        end

        def times_report_path
          @times_report_path ||= ::File.join(log_dir, 'worker_times.txt')
        end

        def log_dir
          @log_dir ||= 'log/ci_queue'
        end

        def worker_env_var
          @worker_env_var ||= 'TEST_ENV_NUMBER'
        end

        def before_fork(&block)
          before_fork_hooks << block
        end

        def after_fork(&block)
          after_fork_hooks << block
        end

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
