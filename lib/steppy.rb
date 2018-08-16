# frozen_string_literal: true

require 'steppy/version'
require 'steppy/cache'
require 'steppy/error'

# The Steppy module you'll include in your classes to give them steps!
module Steppy
  def self.included(base)
    base.extend ClassMethods
    base.include InstanceMethods
  end

  def self.parse_args(args)
    if args.key?(:if)
      args[:condition] = args.delete(:if)
    end

    if args.key?(:unless)
      args[:condition] = -> { !steppy_run_condition(args.delete(:unless)) }
    end

    args
  end

  # Steppy class methods that will be added to your included classes.
  module ClassMethods
    def steppy_cache
      @steppy_cache ||= SteppyCache.new(steps: [], sets: [], rescues: [])
    end

    def step_set(*sets)
      steppy_cache[:sets] += sets
    end

    def step(method = nil, args = {}, &block) # rubocop:disable Airbnb/OptArgParameters
      if method.is_a?(Proc)
        block = method
        method = nil
      end

      steppy_cache[:steps].push(
        method: method,
        args: Steppy.parse_args(args),
        block: block,
      )

      self
    end
    alias stepy_return step

    def step_if(condition, &block)
      steppy_cache[:steps].push(condition: condition, block: block)
      self
    end

    def step_unless(condition, &block)
      steppy_cache[:steps].push(condition: -> { !steppy_run_condition(condition) }, block: block)
      self
    end

    def step_rescue(exceptions = nil, &block) # rubocop:disable Airbnb/OptArgParameters
      steppy_cache[:rescues].push(exceptions: exceptions, block: block)
      self
    end
  end

  # Steppy instance methods that will be added.
  module InstanceMethods
    attr_reader :steppy_attributes, :steppy_result

    def steppy(attributes, cache = {})
      @steppy_attributes = attributes

      steppy_cache.merge!({ prefix: :step }).merge!(cache)

      steppy_run(steppy_cache)
    end

    def steppy_run(steps:, sets:, **)
      sets.each { |key, value| steppy_set(key, value || steppy_attributes[key]) }

      steppy_steps(steps)
    rescue => exception
      steppy_rescue exception, steppy_cache[:rescues]
    end

    def steppy_set(key, value)
      key && instance_variable_set("@#{key}", value)
    end

    def steppy_steps(steps)
      steps.each do |step|
        condition = step[:condition]

        @steppy_result = if condition
          steppy_run_condition_block(condition, step[:block])
        else
          steppy_run_step(step)
        end
      end

      steppy_result
    end

    def steppy_rescue(exception, rescues)
      exception_class = exception.class

      if exception_class == SteppyError || rescues.empty?
        raise exception
      end

      rescues.each do |exceptions:, block:|
        if !exceptions || (exceptions && !exceptions.include?(exception_class))
          @steppy_result = instance_exec(steppy_attributes, &block)
        end
      end

      steppy_result
    end

    def steppy_run_condition_block(condition, block)
      if steppy_run_condition(condition)
        steppy_run(Class.new { include Steppy }.instance_exec(&block).steppy_cache)
      end
    end

    def steppy_run_condition(condition)
      return true unless condition

      if condition.arity > 0
        instance_exec(steppy_attributes, &condition)
      else
        instance_exec(&condition)
      end
    end

    def steppy_run_step(method:, args:, block:)
      return unless steppy_run_condition(args[:condition])

      result = if block
        instance_exec(steppy_attributes, &block)
      else
        steppy_run_method(method, steppy_attributes)
      end

      steppy_set(args[:set], result)

      result
    end

    def steppy_run_method(method_name, attributes)
      method = "#{steppy_cache[:prefix]}_#{method_name}"

      if method(method).arity > 0
        public_send(method, attributes)
      else
        public_send(method)
      end
    end

    def steppy_cache
      @steppy_cache ||= SteppyCache.new(self.class.steppy_cache.to_h)
    end
  end
end
