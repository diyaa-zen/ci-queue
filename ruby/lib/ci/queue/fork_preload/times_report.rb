# frozen_string_literal: true

require 'fileutils'

module CI
  module Queue
    module ForkPreload
      # Same columns a spawn-per-worker harness writes, so whatever reads that file reads both
      # paths identically.
      class TimesReport
        ROW = "%-7s %-8s %-5s\n"

        # ::File, not File: CI::Queue::File shadows it inside this namespace.

        def self.open(path: ForkPreload.times_report_path, &block)
          FileUtils.mkdir_p(::File.dirname(path))
          ::File.open(path, 'w') do |file|
            file.printf(ROW, 'worker', 'seconds', 'exit')
            block.call(new(file))
          end
        end

        def initialize(file)
          @file = file
        end

        def record(worker:, seconds:, exit_code:)
          @file.printf(ROW, worker, seconds, exit_code)
          @file.flush
          warn "[fork-preload] worker #{worker} exited #{exit_code} after #{seconds}s"
        end
      end
    end
  end
end
