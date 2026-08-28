# frozen_string_literal: true

require 'rspec/queue'
require 'ci/queue/fork_preload'

module RSpec
  module Queue
    module ForkPreload
      # A duplicate worker_id silently steals another worker's leases, and a formatter whose
      # --out target is not reopened has all 24 workers writing to one file.
      module Rebindings
        class << self
          def install
            CI::Queue::ForkPreload.after_fork { |number| claim_queue_identity(number) }
            CI::Queue::ForkPreload.after_fork { |number| reopen_formatter_outputs(number) }
          end

          private

          def claim_queue_identity(number)
            RSpec::Queue.config.worker_id = number.to_s
          end

          def reopen_formatter_outputs(number)
            RSpec.configuration.formatters.each do |formatter|
              next unless formatter.respond_to?(:output) && formatter.output.is_a?(::File)

              formatter.output.reopen(per_worker_path(formatter.output.path, number), 'w')
            end
          end

          def per_worker_path(path, number)
            extension = ::File.extname(path)
            ::File.join(::File.dirname(path), "#{::File.basename(path, extension)}_#{number}#{extension}")
          end
        end
      end

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

CI::Queue::ForkPreload::Rebindings.install
RSpec::Queue::ForkPreload::Rebindings.install
