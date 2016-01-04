require "active_support"
require "active_support/test_case"
require "active_support/logger"
require "active_support/testing/autorun"
require "factory_girl"
require "mongoid"
require "mongoid/enum"

ActiveSupport.test_order = :random

module ActiveSupport
  class TestCase
    include FactoryGirl::Syntax::Methods
  end
end

FactoryGirl.find_definitions

# wait until MongoDB instance is ready
if ENV["CI"] == "travis"
  starting = true
  client = Mongo::Client.new(["127.0.0.1:27017"])
  while starting
    begin
      client.command(Mongo::Server::Monitor::STATUS)
      break
    rescue Mongo::Error::OperationFailure
      sleep(2)
      client.cluster.scan!
    end
  end
end

Mongoid.load!("mongoid.yml", :development)
Mongo::Logger.logger = Logger.new("log/test.log")
