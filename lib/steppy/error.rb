# frozen_string_literal: true

# Incase you need to throw an error related to steppy
class SteppyError < StandardError
  attr_reader :step
  # rubocop:disable Airbnb/OptArgParameters
  def initialize(step = nil)
    # rubocop:enable Airbnb/OptArgParameters
    if step
      @step = step
      message = step.to_json
    end

    super(message)
  end
end
