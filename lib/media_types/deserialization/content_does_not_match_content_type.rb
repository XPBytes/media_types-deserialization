require 'media_types/deserialization/error'

module MediaTypes
  module Deserialization
    class ContentDoesNotMatchContentType < Error
      def initialize(source)
        set_backtrace(source.backtrace)
        super source.message
      end
    end
  end
end
