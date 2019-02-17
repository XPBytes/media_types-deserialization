require 'media_types/deserialization/error'

module MediaTypes
  module Deserialization
    class ContentFormatError < defined?(::ActionController) ? ::ActionController::BadRequest : Error
      def initialize(message)
        super message
      end
    end
  end
end
