require 'test_helper'

require 'rack'
require 'rack/request'
require 'action_dispatch'
require 'action_dispatch/http/mime_type'
require 'action_dispatch/http/parameters'

require 'media_types'

module Rack
  class Request
    include ActionDispatch::Http::Parameters
  end
end

class MediaTypes::DeserializationTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::MediaTypes::Deserialization::VERSION
  end

  class BaseController
    include MediaTypes::Deserialization

    def initialize
      @request = Rack::Request.new({ CONTENT_LENGTH: 0, CONTENT_TYPE: 'application/json' })
    end

    attr_accessor :request
  end

  class FakeController < BaseController
    def action(request = self.request)
      self.request = request

      media_type_params
    end
  end

  def setup
    @controller = FakeController.new
  end

  def teardown
    Mime::Type.unregister(:json)
    Mime::Type.unregister(:custom_json)
    Mime::Type.unregister(:base64_encoded_text)

    MediaTypes::Deserialization.configure do
      self.lookup_deserializer_by_symbol = nil
      self.lookup_content_type_symbol = nil
      self.lookup_media_type_by_symbol = nil
    end
  end

  def test_it_does_nothing_if_no_content_type
    assert_equal({}, @controller.action)
  end

  def test_it_does_nothing_if_no_content_length
    request = Rack::Request.new({
      "CONTENT_LENGTH" => 0,
      "CONTENT_TYPE" => 'application/json',
      "#{Rack::RACK_INPUT}" => ''
    })
    assert_equal({}, @controller.action(request))
  end

  def test_it_deserializes_basic_json
    body = '{ "foo": "bar", "numbers": [0, 1, 42] }'

    request = Rack::Request.new({
      "CONTENT_LENGTH" => body.length,
      "CONTENT_TYPE" => 'application/json',
      "#{Rack::RACK_INPUT}" => body
    })

    assert_equal({"foo" => "bar", "numbers" => [0, 1, 42]}, @controller.action(request))
  end

  def test_it_deserializes_registered_json
    Mime::Type.register('application/vnd.xpbytes.special.v1+json', :json)

    body = '{ "foo": "bar", "numbers": [0, 1, 42] }'
    request = Rack::Request.new({
        "CONTENT_LENGTH" => body.length,
        "CONTENT_TYPE" => 'application/vnd.xpbytes.special.v1+json',
        "#{Rack::RACK_INPUT}" => body
    })

    assert_equal({"foo" => "bar", "numbers" => [0, 1, 42]}, @controller.action(request))
  end

  def test_it_deserializes_registered_custom_lookup
    Mime::Type.register('application/vnd.xpbytes.custom.v1+json', :custom_json)
    MediaTypes::Deserialization.lookup_deserializer_by_symbol = proc do |symbol|
      symbol == :custom_json ?
        MediaTypes::Deserialization::DEFAULT_JSON_DESERIALIZER :
        nil
    end

    body = '{ "foo": "bar", "numbers": [0, 1, 42] }'
    request = Rack::Request.new({
        "CONTENT_LENGTH" => body.length,
        "CONTENT_TYPE" => 'application/vnd.xpbytes.custom.v1+json',
        "#{Rack::RACK_INPUT}" => body
    })

    assert_equal({"foo" => "bar", "numbers" => [0, 1, 42]}, @controller.action(request))
  end

  def test_it_deserializes_using_custom_deserializer
    Mime::Type.register('text/vnd.xpbytes.base64.v1', :base64_encoded_text)

    require 'base64'
    decoded = 'This is some custom text'
    encoded = Base64.encode64(decoded)

    MediaTypes::Deserialization.lookup_deserializer_by_symbol = proc do |symbol|
      symbol == :base64_encoded_text ?
          Proc.new { |raw_post| ({ text: Base64.decode64(raw_post) }) } :
          nil
    end

    request = Rack::Request.new({
        "CONTENT_LENGTH" => encoded.length,
        "CONTENT_TYPE" => 'text/vnd.xpbytes.base64.v1',
        "#{Rack::RACK_INPUT}" => encoded
    })

    assert_equal({ text: decoded }, @controller.action(request))
  end

  def test_it_looks_up_content_type_via_custom
    MediaTypes::Deserialization.lookup_content_type_symbol = proc do |content_type|
      content_type.include?('json') ? :json : nil
    end

    body = '{ "foo": "bar", "numbers": [0, 1, 42] }'
    request = Rack::Request.new({
        "CONTENT_LENGTH" => body.length,
        "CONTENT_TYPE" => 'application/vnd.xpbytes.custom.v1+json',
        "#{Rack::RACK_INPUT}" => body
    })

    assert_equal({"foo" => "bar", "numbers" => [0, 1, 42]}, @controller.action(request))
  end

  class CustomMediaTypes
    include MediaTypes::Dsl

    def self.base_format
      'application/vnd.mydomain.%<type>s.v%<version>.s%<view>s+%<suffix>s'
    end

    media_type 'venue', defaults: { suffix: :json, version: 2 }

    validations do
      attribute :name

      attribute :location do
        attribute :latitude, Numeric
        attribute :longitude, Numeric
        attribute :altitude, AllowNil(Numeric), optional: true
      end

      link :self
    end
  end

  def test_it_looks_up_validatable_media_type_via_custom
    Mime::Type.register(CustomMediaTypes.to_constructable.to_s, :venue)
    MediaTypes::Deserialization.lookup_media_type_by_symbol = proc do |symbol|
      symbol == :venue ? CustomMediaTypes.to_constructable : nil
    end

    body = '{ "name": "bar", "_links": { "self": { "href": "https://example.org/venus/1" } } }'
    request = Rack::Request.new({
        "CONTENT_LENGTH" => body.length,
        "CONTENT_TYPE" => CustomMediaTypes.to_constructable.to_s,
        "#{Rack::RACK_INPUT}" => body
    })

    assert_raises MediaTypes::Deserialization::ContentDoesNotMatchContentType do
      @controller.action(request)
    end

    body = '{ "name": "bar", "location": { "latitude": 0.0, "longitude": 0.0 }, "_links": { "self": { "href": "https://example.org/venus/1" } } }'
    request = Rack::Request.new({
        "CONTENT_LENGTH" => body.length,
        "CONTENT_TYPE" => CustomMediaTypes.to_constructable.to_s,
        "#{Rack::RACK_INPUT}" => body
    })

    assert_equal Oj.load(body), @controller.action(request)
  end
end
