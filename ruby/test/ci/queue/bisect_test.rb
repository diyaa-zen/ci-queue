# frozen_string_literal: true
require 'test_helper'
require 'tempfile'

class CI::Queue::BisectTest < Minitest::Test
  def test_config_is_public
    config = CI::Queue::Configuration.new
    config.failing_test = 'ATest#test_bar'

    Tempfile.create('test_order') do |file|
      file.write("ATest#test_foo\nATest#test_bar\n")
      file.flush

      assert_same(config, CI::Queue::Bisect.new(file.path, config).config)
    end
  end
end
