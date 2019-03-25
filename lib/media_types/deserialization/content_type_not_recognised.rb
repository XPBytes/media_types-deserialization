require 'media_types/deserialization/error'

module MediaTypes
  module Deserialization
    class ContentTypeNotRecognised < Error
      def initialize(content_type)
        super format(
          'The Content-Type: %<content_type>s is not recognised or supported',
          content_type: content_type
        )
      end
    end
  end
end
