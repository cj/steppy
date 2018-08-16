# frozen_string_literal: true

# Incase you need to throw an error related to steppy
class SteppyError < StandardError
  attr_reader :steppy
  # rubocop:disable Airbnb/OptArgParameters
  def initialize(steppy = nil)
    # rubocop:enable Airbnb/OptArgParameters
    if steppy
      @steppy = steppy
      message = steppy.is_a?(String) ? steppy : steppy.to_json
    end

    super(message)
  end
end
