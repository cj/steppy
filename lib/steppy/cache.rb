# frozen_string_literal: true

module Steppy
  # https://github.com/jeremyevans/roda/blob/master/lib/roda.rb#L14-L42
  # A thread safe cache class, offering only #[] and #[]= methods,
  # each protected by a mutex.
  class SteppyCache
    # Create a new thread safe cache.
    def initialize(hash = {})
      @mutex = Mutex.new
      @hash  = hash
    end

    # Make getting value from underlying hash thread safe.
    def [](key)
      @mutex.synchronize { @hash[key] }
    end

    # Make setting value in underlying hash thread safe.
    def []=(key, value)
      @mutex.synchronize { @hash[key] = value }
    end
  end
end
