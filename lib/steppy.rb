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

  def self.parse_args!(args)
    if args.key?(:if)
      args[:condition] = args.delete(:if)
    end

    if args.key?(:unless)
      args[:condition] = -> { !steppy_run_condition(args.delete(:unless)) }
    end
  end

  # Steppy class methods that will be added to your included classes.
  module ClassMethods
    def steppy(&block)
      steppy_cache[:klass] = Class.new { include Steppy }.instance_eval(&block)
    end

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

      Steppy.parse_args!(args)

      steppy_cache[:steps].push(
        method: method,
        args: args,
        block: block,
      )

      self
    end

    def step_if(condition, &block)
      steppy_cache[:steps].push(condition: condition, block: block)
      self
    end

    def step_unless(condition, &block)
      steppy_cache[:steps].push(condition: -> { !steppy_run_condition(condition) }, block: block)
      self
    end
  end

  # Steppy instance methods that will be added.
  module InstanceMethods
    attr_reader :steppy_attributes, :steppy_result

    def steppy(attributes, cache = {})
      @steppy_attributes = attributes

      if steppy_cache.key?(:klass)
        return steppy_cache[:klass].new.steppy(attributes, { context: self })
      else
        steppy_cache.merge!({ prefix: :step, context: self }).merge!(cache)
      end

      steppy_run(steppy_cache)
    end

    def steppy_run(steps:, sets:, **)
      steppy_run_sets(sets)
      steppy_run_steps(steps)

      steppy_result
    end

    def steppy_run_sets(sets)
      sets.each { |key, value| steppy_set(key, value || steppy_attributes[key]) }
    end

    def steppy_set(key, value)
      key && steppy_instance.instance_variable_set("@#{key}", value)
    end

    def steppy_run_steps(steps)
      steps.each do |step|
        condition = step[:condition]

        @steppy_result = if condition
          steppy_run_condition_block(condition, step[:block])
        else
          steppy_run_step(step)
        end
      end
    end

    def steppy_run_condition_block(condition, block)
      if steppy_run_condition(condition)
        steppy_run(Class.new { include Steppy }.instance_exec(&block).steppy_cache)
      end
    end

    def steppy_run_condition(condition)
      return true unless condition

      if condition.arity > 0
        steppy_instance.instance_exec(steppy_attributes, &condition)
      else
        steppy_instance.instance_exec(&condition)
      end
    end

    def steppy_run_step(method:, args:, block:)
      return unless steppy_run_condition(args[:condition])

      result = if block
        steppy_instance.instance_exec(steppy_attributes, &block)
      else
        steppy_run_method(method, steppy_attributes)
      end

      steppy_set(args[:set], result)

      result
    end

    def steppy_run_method(method_name, attributes)
      method = "#{steppy_cache[:prefix]}_#{method_name}"

      if steppy_instance.method(method).arity > 0
        steppy_instance.public_send(method, attributes)
      else
        steppy_instance.public_send(method)
      end
    end

    def steppy_cache
      @steppy_cache ||= SteppyCache.new(self.class.steppy_cache.to_h)
    end

    def steppy_instance
      @stepp_context ||= steppy_cache[:context] || self
    end
  end
end
