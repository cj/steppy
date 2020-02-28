# frozen_string_literal: true

module Steppy
  # Steppy class methods that will be added to your included classes.
  module ClassMethods
    def steppy(&block)
      steppy_cache[:block] = block
    end

    def step_set(*sets)
      steppy_cache[:sets] += sets
    end

    def step(method = nil, args = {}, &block)
      steps_cache.push(
        Steppy.parse_step(method: method, args: args, block: block)
      )
      self
    end

    alias step_return step

    def step_if(condition, &block)
      steps_cache.push(condition: condition, block: block)
      self
    end

    def step_unless(condition, &block)
      steps_cache.push(condition: -> { !steppy_run_condition(condition) }, block: block)
      self
    end

    def step_rescue(exceptions = nil, &block)
      steppy_cache[:rescues].push(exceptions: exceptions, block: block)
      self
    end

    def step_if_else(condition_block, step_steps, args = {})
      if_step, else_step = step_steps

      steps_cache.push Steppy.parse_step(
        method: if_step,
        args: {
          if: condition_block,
        }.merge(args)
      )

      steps_cache.push Steppy.parse_step(
        method: else_step,
        args: {
          unless: condition_block,
        }.merge(args)
      )
    end

    def step_after(key = nil, &block)
      step_add_callback(:after, block, key)
    end

    def step_after_all(&block)
      step_add_callback(:after, block, :all)
    end

    def step_before(key = nil, &block)
      step_add_callback(:before, block, key)
    end

    def step_before_all(&block)
      step_add_callback(:before, block, :all)
    end

    def step_add_callback(type, block, key)
      callback_key = key ? key.to_sym : :each
      callbacks = step_callbacks[type][callback_key] ||= []
      callbacks.push(block)
    end

    def steps_cache
      steppy_cache[:steps]
    end

    def step_callbacks
      steppy_cache[:callbacks]
    end

    def steppy_cache
      @steppy_cache ||= SteppyCache.new(
        steps: [],
        sets: [],
        rescues: [],
        callbacks: {
          before: {
            all: [],
            each: [],
          },
          after: {
            all: [],
            each: [],
          },
        }
      )
    end
  end
end
