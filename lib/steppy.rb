# frozen_string_literal: true

require 'steppy/version'
require 'steppy/cache'
require 'steppy/error'
require 'steppy/class_methods'
require 'steppy/instance_methods'

# The Steppy module you'll include in your classes to give them steps!
module Steppy
  def self.included(base)
    base.extend ClassMethods
    base.include InstanceMethods
  end

  # :reek:TooManyStatements
  def self.parse_step(method:, args:, block: nil)
    args[:condition] = -> { steppy_run_condition(args[:if]) } if args.key?(:if)

    args[:condition] = -> { !steppy_run_condition(args[:unless]) } if args.key?(:unless)

    args[:prefix] = :step unless args.key?(:prefix)

    if method.is_a?(Proc)
      block = method
      method = nil
    end

    { method: method, args: args, block: block }
  end
end
