require 'spec_helper'

describe IsItWorking::ActiveRecordCheck do

  let(:status){ IsItWorking::Status.new(:active_record) }

  class IsItWorking::TestActiveRecord < ActiveRecord::Base
  end
  
  it "succeeds if the ActiveRecord connection is active" do
    connection = ActiveRecord::ConnectionAdapters::AbstractAdapter.new(double(:connection))
    connection.stub(active?: true)
    ActiveRecord::Base.stub(connection: connection)
    check = IsItWorking::ActiveRecordCheck.new
    check.call(status)
    status.should be_success
    status.messages.first.message.should == "ActiveRecord::Base.connection is active"
  end
  
  it "allows specifying the class to check the connection for" do
    connection = ActiveRecord::ConnectionAdapters::AbstractAdapter.new(double(:connection))
    connection.stub(active?: true)
    IsItWorking::TestActiveRecord.stub(connection: connection)
    check = IsItWorking::ActiveRecordCheck.new(:class => IsItWorking::TestActiveRecord)
    check.call(status)
    status.should be_success
    status.messages.first.message.should == "IsItWorking::TestActiveRecord.connection is active"
  end

  it "succeeds if the ActiveRecord connection can be reconnected" do
    connection = ActiveRecord::ConnectionAdapters::AbstractAdapter.new(double(:connection))
    # On Rails 4, calling `disconnect!` puts the adapter in a weird state that can't be restored with `verify!`. Using `reconnect!` is ok.
    connection.reconnect!
    connection.stub(active?: true)
    ActiveRecord::Base.stub(connection: connection)
    check = IsItWorking::ActiveRecordCheck.new
    check.call(status)
    status.should be_success
    status.messages.first.message.should == "ActiveRecord::Base.connection is active"
  end

  it "fails if the ActiveRecord connection is not active" do
    connection = ActiveRecord::ConnectionAdapters::AbstractAdapter.new(double(:connection))
    connection.disconnect!
    connection.stub(:verify!)
    ActiveRecord::Base.stub(connection: connection)
    check = IsItWorking::ActiveRecordCheck.new
    check.call(status)
    status.should_not be_success
    status.messages.first.message.should == "ActiveRecord::Base.connection is not active"
  end

  # Use a real database, with as little stubbing as possible
  context "sqlite3" do
    let(:model_class_name) { 'IsItWorkingTestModel'.freeze }
    let(:model_class) { make_ar_klass }

    def make_ar_klass(name = model_class_name)
      klass = Class.new(ActiveRecord::Base) do |k|
        def k.name; to_s; end
      end
      klass_name = name.to_s.dup.freeze
      klass.define_singleton_method(:to_s) { klass_name }
      klass.establish_connection(adapter: 'sqlite3', database: ':memory:')
      klass
    end

    it "succeeds on active connection" do
      model_class = make_ar_klass
      check = IsItWorking::ActiveRecordCheck.new(class: model_class)
      check.call(status)
      status.should be_success
      status.messages.first.message.should == "#{model_class_name}.connection is active"
    end

    it "fails on dead connection" do
      model_class = make_ar_klass
      model_class.connection.disconnect!
      model_class.connection.stub(:verify!)
      check = IsItWorking::ActiveRecordCheck.new(class: model_class)
      check.call(status)
      status.should_not be_success
      status.messages.first.message.should == "#{model_class_name}.connection is not active"
    end
  end
end
