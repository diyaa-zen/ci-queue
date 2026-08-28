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
    # Workers hold an id-to-live-object index so poll can hand back a runnable test, which is
    # why every worker has to load every test file before it can take any work. A worker that
    # resolves an id when it is handed one needs only the files it is actually given.
    #
    # Requiring this file installs the seam but changes nothing: with the flag unset every
    # override falls straight through to super.
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
        # The runner supplies this, because only it knows how to turn one of its own test ids
        # back into something runnable.
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
