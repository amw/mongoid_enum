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

Mongoid.load!("mongoid.yml", :development)
Mongo::Logger.logger = Logger.new("log/test.log")
