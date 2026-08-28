# frozen_string_literal: true

require 'ci/queue'
# Worker lives behind a lazy require in from_uri; lazy loading only makes sense with a
# distributed queue, so pull it in rather than deferring the prepend.
require 'ci/queue/redis'
require 'ci/queue/lazy_load/file_loader'
require 'ci/queue/lazy_load/worker_extension'
require 'ci/queue/lazy_load/static_extension'

module CI
  module Queue
    module LazyLoad
      class FileLoadError < CI::Queue::Error
        attr_reader :file_path, :original_error

        def initialize(file_path, original_error)
          @file_path = file_path
          @original_error = original_error
          super("Failed to load #{file_path}: #{original_error.class}: #{original_error.message}")
          set_backtrace(original_error.backtrace)
        end
      end

      class << self
        attr_accessor :index_builder

        def enabled?
          ENV['CI_QUEUE_LAZY_LOAD'] == '1' && !index_builder.nil?
        end

        def build_index
          index_builder.call
        end
      end
    end
  end
end

CI::Queue::Redis::Worker.prepend(CI::Queue::LazyLoad::WorkerExtension)
CI::Queue::Static.prepend(CI::Queue::LazyLoad::StaticExtension)
