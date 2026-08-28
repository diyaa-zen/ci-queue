# frozen_string_literal: true

module CI
  module Queue
    module LazyLoad
      # Retry < Static and the retry path swaps the queue object, so a worker resolving on
      # demand needs the same seam here or a retry crashes on a missing index entry.
      module StaticExtension
        def populate(tests, random: nil)
          return super unless LazyLoad.enabled?

          @lazy_index = LazyLoad.build_index
          self
        end

        def populated?
          !@lazy_index.nil? || super
        end

        def index
          @lazy_index || super
        end
      end
    end
  end
end
