require 'spec_helper'

describe Hobson::RedisHash do

  before do
    @redis = RedisMonitor.new(Redis.new)
    @redis.flushall
    @redis.method_calls.clear
  end

  def new_hash
    Hobson::RedisHash.new(@redis, 'testing')
  end

  it "should read and write to redis as little as possible" do
    hash = new_hash
    @redis.method_calls.length.should == 0
    hash.keys.should == []
    @redis.method_calls.length.should == 1
    hash['name'] = 'steve'
    @redis.method_calls.length.should == 2
    hash['name'].should == 'steve'
    @redis.method_calls.length.should == 2

    hash = new_hash
    @redis.method_calls.length.should == 2
    hash.keys.should == ['name']
    @redis.method_calls.length.should == 3
    hash['name'].should == 'steve'
    @redis.method_calls.length.should == 3

    hash.reload!
    @redis.method_calls.length.should == 3
    hash['name'].should == 'steve'
    @redis.method_calls.length.should == 4
    hash['name'].should == 'steve'
    @redis.method_calls.length.should == 4
  end

  it "should marshal everything" do
    hash1 = new_hash
    hash1['a string']   = "hello"
    hash1['an integer'] = 12
    hash1['a float']    = 8.98
    hash1['a time']     = Time.now

    hash1['a string'].should   be_a String
    hash1['an integer'].should be_a Integer
    hash1['a float'].should    be_a Float
    hash1['a time'].should     be_a Time

    hash2 = new_hash
    hash2['a string'].should   ==  hash1['a string']
    hash2['an integer'].should ==  hash1['an integer']
    hash2['a float'].should    ==  hash1['a float']
    hash2['a time'].should     ==  hash1['a time']

    hash2['a string'].should   be_a String
    hash2['an integer'].should be_a Integer
    hash2['a float'].should    be_a Float
    hash2['a time'].should     be_a Time
  end

  # describe "#reject" do
  #   it "should operate on a clone of the cache hash" do
  #     hash1 = new_hash
  #     hash1['x'] = 42
  #     hash1['y'] = 69
  #     hash1.reject{|k,v| k == 'x'}.should == {'y' => 69}
  #   end
  # end

end
