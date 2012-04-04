require 'spec_helper'

describe Hobson::Cache do

  it 'should respond to write and read' do
    Hobson::Cache.write(:a, :b).should == :b
    Hobson::Cache.read(:a).should == :b
  end

  it 'should respond to delete' do
    Hobson::Cache.write(:a, :b).should == :b
    Hobson::Cache.delete(:a).should == :b
  end

  it 'should respond to fetch' do
    Hobson::Cache.fetch(:a) { :b }.should == :b
    Hobson::Cache.read(:a).should == :b
    Hobson::Cache.fetch(:a) { :c }.should == :b
    Hobson::Cache.delete(:a).should == :b
    Hobson::Cache.fetch(:a) { :c }.should == :c
  end

  it 'should respond to has_key?' do
    Hobson::Cache.write(:a, :b).should == :b
    Hobson::Cache.has_key?(:a).should be_true
    Hobson::Cache.has_key?(:NOT_FOUND).should be_false
  end

  it 'should build the proper cache key for models and other objects' do
    Hobson::Cache.build_key(Hobson::Project::TestRun.new(nil, 1)).should == "Hobson::Project::TestRun-1"
    Hobson::Cache.build_key(Hobson::Project::TestRun.new(nil, 2), :specific).should == "Hobson::Project::TestRun-2-specific"
    Hobson::Cache.build_key(:abc).should == :abc
    Hobson::Cache.build_key("123", :ab).should == "123-ab"
  end

  it 'should respond to clear' do
    Hobson::Cache.write(:a, :b).should == :b
    Hobson::Cache.has_key?(:a).should be_true
    Hobson::Cache.clear
    Hobson::Cache.has_key?(:a).should be_false
  end

end
