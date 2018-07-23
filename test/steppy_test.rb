# frozen_string_literal: true

require 'test_helper'

class RegisterBase
  include Steppy

  def self.call(params)
    new.steppy(params)
  end
end

class Register < RegisterBase
  steppy do
    step_set :email

    step :create_user, set: :user
    step :set_user_role, if: -> { @user.role.nil? }

    step_if -> { @user.role == 'admin' } do
      step(:do_admin_things) { @admin = true }
    end

    step :send_welcome_email do |first_name:, last_name:, **params|
      # send email

      {
        first_name: first_name,
        last_name: last_name,
        user: @user,
        email_sent: true,
        admin: @admin,
      }
    end
  end

  def step_create_user(first_name:, last_name:, **params)
    User.new(first_name, last_name, @email, params[:role])
  end

  def step_set_user_role
    @user.role = 'basic'
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

    response[:user].email.must_equal user_details[:email]
    response[:user].role.must_equal 'basic'
    response[:admin].must_be_nil
  end

  test 'registering as an admin' do
    response = Register.call(user_details.merge(role: 'admin'))

    response[:user].email.must_equal user_details[:email]
    response[:user].role.must_equal 'admin'
    response[:admin].must_equal true
  end

  test 'step if: with attributes' do
    klass = Class.new do
      include Steppy

      step :return_bar, if: ->(value:) { value == 'foo' }

      def step_return_bar
        'bar'
      end
    end

    klass.new.steppy(value: 'foo').must_equal 'bar'
    klass.new.steppy(value: 'bar').must_be_nil
  end

  test 'step_if with attributes' do
    klass = Class.new do
      include Steppy

      step_if ->(value:) { value == 'foo' } do
        step :return_bar
      end

      def step_return_bar
        'bar'
      end
    end

    klass.new.steppy(value: 'foo').must_equal 'bar'
    klass.new.steppy(value: 'bar').must_be_nil
  end

  test 'only run prefix' do
    klass = Class.new do
      include Steppy

      step :set_foo, set: :foo
      step :set_bar, set: :bar, prefix: :filter
      step :return_result

      def step_set_foo
        'foo'
      end

      def filter_set_bar
        'bar'
      end

      def step_return_result
        { foo: @foo, bar: @bar }
      end
    end

    klass.new.steppy({}, prefix: :filter).must_be_nil
  end

  test 'having no steps should not throw an error' do
    klass = Class.new do
      include Steppy
    end

    klass.new.steppy(foo: 'bar').must_be_nil
  end

  test 'it should raise a SteppyError' do
    klass = Class.new do
      include Steppy

      step :foo do
        raise SteppyError.new({
          bar: 'foo',
        })
      end
    end

    error = -> { klass.new.steppy({}) }.must_raise SteppyError
    error.step[:bar].must_equal 'foo'
    error.message.must_equal error.step.to_json
  end
end
