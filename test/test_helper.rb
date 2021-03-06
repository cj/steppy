# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'byebug'
require 'simplecov'

SimpleCov.start do
  add_filter '/.bundle/'
end

require 'steppy'

require 'minitest/autorun'
require 'minitest/spec'

module Minitest
  class Test
    extend MiniTest::Spec::DSL

    class << self
      alias test it
    end
  end
end
