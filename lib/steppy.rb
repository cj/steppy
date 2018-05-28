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
    def step_set(*sets)
      steppy[:sets] = *sets
    end

    def step(method, **args)
      steppy_steps << { step_method: method, step_args: args }
    end

    def step_if(condition, &block)
      steppy_steps << { step_if: condition, step_block: block }
    end

    def steppy
      @steppy ||= SteppyCache.new(steps: nil, sets: [], block: nil)
    end

    def steppy_steps
      steppy[:steps] ||= []
    end

    def steps(&block)
      steppy[:block] = block
    end
  end

  # Steppy instance methods that will be added.
  module InstanceMethods
    def steppy(attributes)
      @steppy = { attributes: attributes.freeze }

      steppy_run_sets
      steppy_run_all

      @steppy[:result]
    end

    def steppy_attributes
      @steppy[:attributes]
    end

    protected

    def steppy_run_sets
      self.class.steppy[:sets].each do |set|
        steppy_set(set, steppy_attributes[set])
      end
    end

    def steppy_run_all
      steppy = self.class.steppy
      steps = steppy[:steps] ||= steppy_class.instance_exec(&steppy[:block])

      steps.each do |step|
        @steppy[:result] = step.key?(:step_if) ? steppy_if_block(step) : steppy_step(step)
      end
    end

    def steppy_step(step_method:, step_args:)
      method_name = "step_#{step_method}"

      steppy_if(step_args[:if]) && return

      if method(method_name).arity > 0
        result = public_send(method_name, steppy_attributes)
      else
        result = public_send(method_name)
      end

      steppy_set(step_args[:set], result)
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

      passed && steppy_class.instance_exec(&step_block).each do |step|
        steppy_step(step)
      end
    end

    def steppy_class
      Class.new { include Steppy }
    end
  end
end
