# frozen_string_literal: true

require 'steppy/version'
require 'steppy/cache'

# The Steppy module you'll include in your classes to give them steps!
module Steppy
  def self.included(base)
    base.extend ClassMethods
    base.include InstanceMethods
  end

  # Steppy class methods that will be added to your included classes.
  module ClassMethods
    if !defined? step
      def step(method, **args, &block)
        args[:prefix] ||= :step
        steppy_add step_method: method, step_args: args, step_block: block
      end
    end

    if !defined? step_if
      def step_if(condition, &block)
        steppy_add step_if: condition, step_block: block
      end
    end

    if !defined? step_set
      def step_set(*sets)
        steppy_cache[:sets] = *sets
      end
    end

    def steppy_cache
      @steppy_cache ||= SteppyCache.new(steps: nil, sets: [], block: nil)
    end

    def steppy_steps
      steppy_cache[:steps] ||= []
    end

    def steppy_add(step)
      steppy_steps.push(step)
      steppy_cache
    end

    def steppy(&block)
      steppy_cache[:block] = block
    end
  end

  # Steppy instance methods that will be added.
  module InstanceMethods
    def steppy(attributes, prefix: :step)
      @steppy_prefix = prefix
      @steppy = { attributes: attributes.freeze }

      steppy_run(
        (steppy_class_block || steppy_class_cache).to_h
      )
    end

    def steppy_attributes
      @steppy[:attributes]
    end

    protected

    def steppy_run(steps:, sets:, **)
      steppy_run_sets(sets)
      steppy_run_steps(steps)

      @steppy[:result] || nil
    end

    def steppy_class_block
      block = steppy_class_cache[:block]
      block && steppy_class.instance_exec(&block)
    end

    def steppy_class_cache
      self.class.steppy_cache
    end

    def steppy_run_sets(sets)
      sets ||= steppy_class_cache[:sets]

      sets.each do |set|
        steppy_set(set, steppy_attributes[set])
      end
    end

    def steppy_run_steps(steps)
      if !steps
        return
      end

      steps.each do |step|
        @steppy[:result] = step.key?(:step_if) ? steppy_if_block(step) : steppy_step(step)
      end
    end

    def steppy_step(step_method:, step_args:, step_block:)
      if steppy_if(step_args[:if]) || @steppy_prefix != step_args[:prefix]
        return
      end

      method_name = "#{@steppy_prefix}_#{step_method}"

      result = if step_block
                 steppy_run_block(step_block, steppy_attributes)
               else
                 steppy_run_method(method_name, steppy_attributes)
               end

      steppy_set(step_args[:set], result)
    end

    def steppy_run_method(method_name, steppy_attributes)
      if method(method_name).arity > 0
        public_send(method_name, steppy_attributes)
      else
        public_send(method_name)
      end
    end

    def steppy_run_block(step_block, steppy_attributes)
      if step_block.arity > 0
        instance_exec(steppy_attributes, &step_block)
      else instance_exec(&step_block)
      end
    end

    def steppy_if(step_if)
      return unless step_if

      if step_if.arity > 0
        !instance_exec(steppy_attributes, &step_if)
      else
        !instance_exec(&step_if)
      end
    end

    def steppy_set(step_set, result)
      step_set && instance_variable_set("@#{step_set}", result)

      result
    end

    def steppy_if_block(step_if:, step_block:)
      passed = if step_if.arity > 0
                 instance_exec(steppy_attributes, &step_if)
               else
                 instance_exec(&step_if)
               end

      passed && steppy_run(steppy_class.instance_exec(&step_block).to_h)
    end

    def steppy_class
      Class.new { include Steppy }
    end
  end
end
