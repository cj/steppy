# frozen_string_literal: true

require 'test_helper'

class RegisterBase
  include Steppy

  def self.call(params)
    new.steppy(params)
  end
end

class Register < RegisterBase
  step_set :email

  step :create_user, set: :user
  step :set_user_role, if: -> { @user.role.nil? }

  step_if -> { @user.role == 'admin' } do
    step :do_admin_things
  end

  step :send_welcome_email

  def step_create_user(first_name:, last_name:, **params)
    User.new(first_name, last_name, @email, params[:role])
  end

  def step_set_user_role
    @user.role = 'basic'
  end

  def step_do_admin_things
    @admin = true
  end

  def step_send_welcome_email
    # send email

    {
      user: @user,
      email_sent: true,
      admin: @admin,
    }
  end

  User = Struct.new(:first_name, :last_name, :email, :role)
end

class SteppyTest < Minitest::Test
  let(:user_details) do
    {
      first_name: 'foo',
      last_name: 'bar',
      email: 'foo@bar.com',
    }
  end

  test 'it has a version number' do
    ::Steppy::VERSION.wont_be_nil
  end

  test 'registering as basic user' do
    response = Register.call(user_details)

    response[:user].role.must_equal 'basic'
    response[:admin].must_be_nil
  end

  test 'registering as an admin' do
    response = Register.call(user_details.merge(role: 'admin'))

    response[:user].role.must_equal 'admin'
    response[:admin].must_equal true
  end
end
