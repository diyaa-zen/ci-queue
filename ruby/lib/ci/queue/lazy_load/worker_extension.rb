# frozen_string_literal: true

module CI
  module Queue
    module LazyLoad
      # poll does `index.fetch(test)`, so overriding `index` alone is enough to make it resolve
      # on demand. The poll loop itself is untouched.
      module WorkerExtension
        def populate(tests, random: Random.new)
          return super unless LazyLoad.enabled?

          @lazy_index = LazyLoad.build_index
          # This worker contributes nothing to the queue, so it must not win the election:
          # it would push an empty queue and the build would run no tests at all.
          @master = false
          self
        end

        def populated?
          !@lazy_index.nil? || super
        end

        def index
          @lazy_index || super
        end

        # push sets @total on the leader. A worker that never pushes has none, and requeue
        # computes global_max_requeues(total), which cannot take nil.
        def total
          super || redis.get(key('total'))&.to_i
        end
      end
    end
  end
end
