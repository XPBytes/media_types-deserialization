# frozen_string_literal: true

require "media_types/deserialization/version"

require 'active_support/concern'
require 'active_support/core_ext/module/attribute_accessors'

require 'media_types/scheme/errors'

require 'media_types/deserialization/error'
require 'media_types/deserialization/content_does_not_match_content_type'
require 'media_types/deserialization/content_format_error'
require 'media_types/deserialization/content_type_not_recognised'

require 'http_headers/content_type'

module MediaTypes
  module Deserialization
    extend ActiveSupport::Concern

    PARAMETERS_KEY = 'api.media_type_deserializer.request.parameters'

    DEFAULT_JSON_DESERIALIZER = lambda do |raw_post|
      require 'oj'
      data = Oj.load(raw_post, Oj.default_options) || {}
      data.is_a?(::Hash) ? data : { _json: data }
    end

    DEFAULT_LOOKUP_TABLE = {
      'application/json' => :json,
      'text/xml' => :xml,
      'text/html' => :html
    }

    mattr_accessor :lookup_content_type_symbol, :lookup_deserializer_by_symbol, :lookup_media_type_by_symbol

    def self.configure(&block)
      block_given? ? instance_exec(self, &block) : self
    end

    # Returns both GET and POST \parameters in a single hash.
    def media_type_params
      # If this has been parsed before, e.g. in a middleware, return directly
      previous_params = request.get_header(PARAMETERS_KEY)
      return previous_params if previous_params

      deserialize_content.tap do |params|
        params.merge!(request.path_parameters)
        request.set_header(PARAMETERS_KEY, params)
      end
    rescue StandardError => ex
      if defined?(::Oj::Error) && ex.is_a?(::Oj::Error)
        raise ContentFormatError, 'Body is not valid JSON: ' + ex.message
      end

      raise ex
    end

    private

    def request_content_type?
      request.content_type && request.content_length.positive?
    end

    def request_content_type
      @request_content_type ||= HttpHeaders::ContentType.new(request.content_type)&.content_type
    end

    def request_content_type_symbol
      content_type = request_content_type
      return nil unless content_type
      result = lookup_content_type_symbol.respond_to?(:call) ?
        instance_exec(content_type, &lookup_content_type_symbol) :
        lookup_content_type_via_mime_type(content_type)

      raise ContentTypeNotRecognised, content_type unless result
      return result if result.is_a?(Symbol)
      (result.respond_to?(:symbol) && result.symbol) || result.to_sym || DEFAULT_LOOKUP_TABLE[result.to_s]
    end

    def lookup_content_type_via_mime_type(content_type)
      require 'action_dispatch/http/mime_type'
      Mime::Type.lookup(content_type)
    end

    def deserializer_for_content_type(symbol = request_content_type_symbol)
      if lookup_deserializer_by_symbol.respond_to?(:call)
        deserializer = instance_exec(symbol, &lookup_deserializer_by_symbol)
        return deserializer if deserializer
      end

      next_symbol = symbol

      if lookup_media_type_by_symbol.respond_to?(:call) && symbol != :json
        media_type = instance_exec(symbol, &lookup_media_type_by_symbol)
        next_symbol = media_type.respond_to?(:symbol) && media_type.symbol || media_type&.suffix
        return deserializer_for_content_type(next_symbol) if next_symbol != symbol && next_symbol
      end

      return nil unless symbol == :json || next_symbol == :json
      DEFAULT_JSON_DESERIALIZER
    end

    def deserialize_content(body = request.body)
      symbol = request_content_type_symbol
      deserializer = deserializer_for_content_type(symbol)
      return {} unless deserializer

      deserializer.call(body).tap do |deserialized|
        if lookup_media_type_by_symbol.respond_to?(:call)
          media_type = instance_exec(symbol, &lookup_media_type_by_symbol)
          media_type&.validate!(deserialized)
        end
      end
    rescue ::MediaTypes::Scheme::ValidationError => ex
      raise ContentDoesNotMatchContentType, ex
    end
  end
end
