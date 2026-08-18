# frozen_string_literal: true
require 'test_helper'

class CI::Queue::BisectTest < Minitest::Test
  TEST_LIST_PATH = '/tmp/bisect-queue-test.txt'.freeze

  def test_config_is_public
    config = CI::Queue::Configuration.new(failing_test: 'ATest#test_bar')
    File.write(TEST_LIST_PATH, "ATest#test_foo\nATest#test_bar\n")

    assert_same(config, CI::Queue::Bisect.new(TEST_LIST_PATH, config).config)
  end
end
