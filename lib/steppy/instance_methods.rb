# frozen_string_literal: true

module Steppy
  # Steppy instance methods that will be added.
  module InstanceMethods
    attr_reader :steppy_cache

    def steppy(attributes = {}, cache = {})
      steppy_initialize_cache({ attributes: attributes, prefix: :step }.merge(cache))

      step_run_callbacks(:before, :all, attributes)

      result = if steppy_cache.key?(:block)
        instance_exec(&steppy_cache[:block])
      else
        steppy_run(steppy_cache)
      end

      step_run_callbacks(:after, :all, attributes)

      result
    rescue StandardError => exception
      steppy_rescue exception, steppy_cache[:rescues]
    end

    def step_set(*sets)
      steppy_sets(sets)
    end

    def step(method = nil, args = {}, &block)
      steppy_run_step Steppy.parse_step(method: method, args: args, block: block)
    end

    alias step_return step

    def step_if_else(condition_block, step_steps, args = {})
      if_step, else_step = step_steps

      steppy_run_step Steppy.parse_step(
        method: if_step,
        args: {
          if: condition_block,
        }.merge(args)
      )

      steppy_run_step Steppy.parse_step(
        method: else_step,
        args: {
          unless: condition_block,
        }.merge(args)
      )
    end

    def step_if(condition, &block)
      steppy_run_condition_block condition, block
    end

    def step_unless(condition, &block)
      steppy_run_condition_block -> { !steppy_run_condition(condition) }, block
    end

    def step_rescue(*)
      raise '#step_rescue can not be used in a block, please just add rescue to the #steppy block.'
    end

    protected

    def steppy_run(steps:, sets:, **)
      steppy_sets(sets)
      steppy_steps(steps)
    end

    def steppy_sets(sets)
      sets.each { |key, value| steppy_set(key, value || steppy_attributes[key]) }
    end

    def steppy_set(key, value)
      key && instance_variable_set("@#{key}", value)
    end

    def steppy_steps(steps)
      steps.each do |step|
        condition = step[:condition]

        steppy_cache[:result] = if condition
          steppy_run_condition_block(condition, step[:block])
        else
          steppy_run_step(step)
        end
      end

      steppy_result
    end

    def steppy_rescue(exception, rescues)
      exception_class = exception.class
      has_exception = exception_class == SteppyError || rescues.empty?

      raise exception if has_exception

      rescues.each do |exceptions:, block:|
        if !exceptions || (exceptions && !exceptions.include?(exception_class))
          steppy_cache[:result] = instance_exec(steppy_attributes, &block)
        end
      end

      steppy_result
    end

    def steppy_run_condition_block(condition, block)
      steppy_run(steppy_cache_from_block(block)) if steppy_run_condition(condition)
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
      if !steppy_run_condition(args[:condition]) || (steppy_cache[:prefix] != args[:prefix])
        return steppy_result
      end

      step_run_callbacks(:before, method, args, args)

      result = if block
        instance_exec(steppy_attributes, &block)
      else
        steppy_run_method(method, steppy_attributes)
      end

      step_run_callbacks(:after, method, result, args)

      steppy_set(args[:set], result)

      result
    end

    def step_run_callbacks(type, method, result, args = result)
      callbacks = step_callbacks[type]
      method_callbacks = callbacks[method] || []

      if method != :all
        callbacks[:each].each do |callback|
          instance_exec(result, args, &callback)
        end
      end

      method_callbacks.each do |callback|
        instance_exec(result, args, &callback)
      end
    end

    def steppy_run_method(method_name, attributes)
      method = "#{steppy_cache[:prefix]}_#{method_name}"

      if method(method).arity > 0
        public_send(method, attributes)
      else
        public_send(method)
      end
    end

    def step_callbacks
      steppy_cache[:callbacks]
    end

    def steppy_cache_from_block(block)
      Class.new { include Steppy }.instance_exec(&block).steppy_cache
    end

    def steppy_initialize_cache(cache)
      @steppy_cache = SteppyCache.new(
        self.class.steppy_cache.to_h.merge(result: nil).merge(cache)
      )
    end

    def steppy_attributes
      steppy_cache[:attributes]
    end

    def steppy_result
      steppy_cache[:result]
    end
  end
end
