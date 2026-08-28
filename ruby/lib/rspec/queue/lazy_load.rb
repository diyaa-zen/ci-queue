# frozen_string_literal: true

require 'set'
require 'rspec/queue'
require 'ci/queue/lazy_load'

module RSpec
  module Queue
    module LazyLoad
      # An RSpec example id already names the file it came from, so nothing has to be carried
      # alongside it through the queue. Upstream's minitest resolver needs a file_path in the
      # queue entry because Class#method ids do not name their file.
      class Index
        ID_LOCATION = /\[[\d:]+\]\z/

        def initialize(loader: CI::Queue::LazyLoad::FileLoader.new)
          @loader = loader
          @examples = {}
          @absorbed_groups = Set.new
        end

        # Named fetch because that is what the untouched poll loop calls on the index.
        def fetch(test_id)
          known = @examples[test_id]
          return known if known

          @loader.load_file(file_for(test_id))
          absorb_new_example_groups
          @examples.fetch(test_id)
        end

        def load_stats
          @loader.load_stats
        end

        private

        def file_for(test_id)
          test_id.sub(ID_LOCATION, '')
        end

        # Loading a file appends its top-level groups to the world, so only roots we have not
        # walked yet can hold examples we have not indexed.
        def absorb_new_example_groups
          RSpec.world.example_groups.each do |root|
            next unless @absorbed_groups.add?(root.object_id)

            root.descendants.each do |group|
              group.filtered_examples.each do |example|
                @examples[example.id] = SingleExample.new(group, example)
              end
            end
          end
        end
      end

      # The helpers named by .rspec --require come through a different path, so the app, its
      # suite hooks and its factories still boot. Only the spec files are deferred.
      module SkipSpecFileLoading
        def load_spec_files
          return if CI::Queue::LazyLoad.enabled?

          super
        end
      end
    end
  end
end

RSpec::Core::Configuration.prepend(RSpec::Queue::LazyLoad::SkipSpecFileLoading)
CI::Queue::LazyLoad.index_builder = -> { RSpec::Queue::LazyLoad::Index.new }
