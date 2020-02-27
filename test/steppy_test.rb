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
    step(:do_admin_things) { @admin = true }
  end

  step :send_welcome_email do |first_name:, last_name:, **_params|
    # send email

    {
      first_name: first_name,
      last_name: last_name,
      user: @user,
      email_sent: true,
      admin: @admin,
    }
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

  test 'different prefix' do
    klass = Class.new do
      include Steppy

      step :set_foo, set: :foo
      step :set_bar, set: :bar, prefix: :filter
      step_return { 'foo' }

      def filter_set_bar
        'bar'
      end
    end

    klass.new.steppy({}, prefix: :filter).must_equal 'bar'
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
        raise SteppyError, bar: 'foo'
      end
    end

    error = -> { klass.new.steppy({}) }.must_raise SteppyError
    error.steppy[:bar].must_equal 'foo'
    error.message.must_equal error.steppy.to_json
  end

  test '#unless' do
    klass = Class.new do
      include Steppy

      step :foo, unless: -> { @bar }, set: :foo
      step_unless -> { @bar } do
        step :set_bar, set: :bar
      end
      step ->(baz:) { @foo + @bar + baz }

      def step_foo
        'foo'
      end

      def step_set_bar
        'bar'
      end
    end

    klass.new.steppy(baz: 'baz').must_equal 'foobarbaz'
  end

  test 'step as block only' do
    klass = Class.new do
      include Steppy

      step { |bar:| "foo#{bar}" }
    end

    klass.new.steppy(bar: 'bar').must_equal 'foobar'
  end

  test 'rescue' do
    klass = Class.new do
      include Steppy

      step { raise 'o noes' }
      step_rescue { |args| "#{args.to_json} error raised" }
    end

    args = { bar: 'bar' }
    klass.new.steppy(args).must_equal "#{args.to_json} error raised"
  end

  test 'do no rescue SteppyError\'s' do
    klass = Class.new do
      include Steppy

      step { raise SteppyError, 'o noes' }
      step_rescue { |args| "#{args.to_json} error raised" }
    end

    error = -> { klass.new.steppy({}) }.must_raise SteppyError
    error.message.must_equal 'o noes'
  end

  test 'allow to wrap in a steppy block' do
    klass = Class.new do
      include Steppy

      steppy do
        step { 'foo' }
      end
    end

    klass.new.steppy({}).must_equal 'foo'
  end

  test 'step_if_else' do
    klass = Class.new do
      include Steppy

      attr_reader :current_user

      step_if_else -> { current_user }, %i(
        initialize_current_user
        initialize_anonymous_user
      ), set: :result

      step_return { @result }

      def step_initialize_current_user
        'current_user'
      end

      def step_initialize_anonymous_user
        'anonymous_user'
      end

      def current_user
        steppy_attributes[:current_user]
      end
    end

    klass.new.steppy(current_user: false).must_equal 'anonymous_user'
    klass.new.steppy(current_user: true).must_equal 'current_user'
  end

  test 'step_if_else inside a steppy block' do
    klass = Class.new do
      include Steppy

      attr_reader :current_user

      steppy do
        step_if_else -> { current_user }, %i(
          initialize_current_user
          initialize_anonymous_user
        ), set: :result

        step_return { @result }
      end

      def step_initialize_current_user
        'current_user'
      end

      def step_initialize_anonymous_user
        'anonymous_user'
      end

      def current_user
        steppy_attributes[:current_user]
      end
    end

    klass.new.steppy(current_user: false).must_equal 'anonymous_user'
    klass.new.steppy(current_user: true).must_equal 'current_user'
  end

  test 'step callbacks' do
    klass = Class.new do
      include Steppy

      attr_reader :current_user

      step :initialize_current_user

      step_before { puts 'before:global' }

      step_before :initialize_current_user do |_args|
        puts 'before:initialize_current_user'
      end

      step_after :initialize_current_user do |result|
        puts "after:#{result}"
      end

      step_after { puts 'after:global' }

      def step_initialize_current_user
        'current_user'
      end
    end

    output, error = capture_io do
      klass.new.steppy
    end

    output.must_include 'before:initialize_current_user'
    output.must_include 'before:global'
    output.must_include 'after:current_user'
    output.must_include 'after:global'

    error.must_be_empty
  end
end
