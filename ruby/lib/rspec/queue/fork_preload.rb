# frozen_string_literal: true

require 'rspec/queue'
require 'ci/queue/fork_preload'

module RSpec
  module Queue
    module ForkPreload
      # run_specs is the last point before any queue traffic, so the fork lands here and every
      # child builds its own connections rather than sharing the parent's.
      module RunnerHook
        def run_specs(example_groups)
          return super unless CI::Queue::ForkPreload.enabled?

          CI::Queue::ForkPreload::Supervisor.new.run { super(example_groups).to_i }
        end
      end
    end
  end
end

RSpec::Queue::Runner.prepend(RSpec::Queue::ForkPreload::RunnerHook)
