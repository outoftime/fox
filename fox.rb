require 'rubygems'
require 'active_support'
require 'redis'

module Fox
  module Document
    extend ActiveSupport::Concern

    module ClassMethods
      def [](id)
        allocate.tap do |instance|
          instance.instance_eval { @id = id }
        end
      end

      def string(name)
        name = name.to_s
        module_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{name}
            redis.get("fox/attrs/\#{id}/" + #{name.inspect})
          end

          def #{name}=(value)
            redis.set("fox/attrs/\#{id}/" + #{name.inspect}, value)
          end
        RUBY
      end

      def list(name)
        name = name.to_s
        module_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{name}
            Fox::List.new(#{name.inspect}, id, redis)
          end
        RUBY
      end

      def integer(name)
        name = name.to_s
        module_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{name}
            Fox::Integer.new(#{name.inspect}, id, redis)
          end

          def #{name}=(value)
            redis.set("fox/attrs/\#{id}/" + #{name.inspect}, value)
          end
        RUBY
      end
    end

    module InstanceMethods
      def id
        @id || redis.incr('fox/id_sequence')
      end

      private

      def redis
        @redis ||= Redis.new
      end
    end
  end

  module Datum
    private

    def key
      @key ||= "fox/attrs/#{@document_id}/#{@name}"
    end
  end

  class List
    include Enumerable
    include Datum

    def initialize(name, document_id, redis)
      @name, @document_id, @redis = name, document_id, redis
    end

    def <<(value)
      @redis.rpush(key, value)
    end

    def [](index)
      @redis.lindex(key, index)
    end

    def []=(index, value)
      @redis.lset(key, index, value)
    end

    def length
      @redis.llen(key)
    end

    def pop
      @redis.rpop(key)
    end

    def shift
      @redis.lpop(key)
    end

    def unshift(value)
      @redis.lpush(key, value)
    end

    def each(&block)
      @redis.lrange(key, 0, -1).each(&block)
    end

    def inspect
      to_a.inspect
    end
  end

  class Integer < BasicObject
    include Datum

    instance_methods.each do |method|
      undef_method(method) unless method =~ /^__.*__/
    end

    def initialize(name, document_id, redis)
      @name, @document_id, @redis = name, document_id, redis
    end

    def incr(step = nil)
      if step.nil?
        @redis.incr(key)
      else
        @redis.incrby(key, step)
      end
    end

    def decr(step = nil)
      if step.nil?
        @redis.decr(key)
      else
        @redis.decrby(key, step)
      end
    end

    def method_missing(name, *args, &block)
      value.__send__(name, *args, &block)
    end

    private

    def value
      @redis.get(key).to_i
    end
  end
end
