# MediaTypes::Deserialization

[![Build Status: master](https://travis-ci.com/XPBytes/media_types-deserialization.svg)](https://travis-ci.com/XPBytes/media_types-deserialization)
[![Gem Version](https://badge.fury.io/rb/media_types-deserialization.svg)](https://badge.fury.io/rb/media_types-deserialization)
[![MIT license](http://img.shields.io/badge/license-MIT-brightgreen.svg)](http://opensource.org/licenses/MIT)

Add media types supported deserialization using your favourite deserializer, and (when supported and provided) media 
type validation.


## Deprecated since `media-types-serialization@1.0.0`

This library will nog longer receive updates because it has been completely obsoleted by changes in the `media-types-serialization`. That library now takes care of both input and output.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'media_types-deserialization'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install media_types-deserialization

## Usage

All logic lives in the `MediaTypes::Deserialization` and the main method you'll use is `media_type_params`. This works
very similarly as `params` in `Rack` (and therefore `Rails`) applications, but only gives back what the implicit or
explicit deserializer gives back.

```ruby
require 'media_types/deserialization'

class BaseController
  include MediaTypes::Deserialization
  
  rescue_from ContentFormatError, with: :bad_request # 400
  rescue_from ContentTypeNotRecognised, with: :unsupported_media_type # 415
  rescue_from ContentDoesNotMatchContentType, with: :unprocessable_entity # 422 
end
```

### Content Type lookup (symbol)

If you _don't_ provide the `lookup_content_type_symbol` configuration, it requires `'action_dispatch/http/mime_type'` to
be present in order to look-up the content type symbol. This is true for `Rails` applications by default.

```ruby
MediaTypes::Deserialization.configure do
  self.lookup_content_type_symbol = lambda do |content_type|
    # For example use a lookup map
    KNOWN_CONTENT_TYPES_TO_SYMBOL[content_type]
    
    # Or alternatively use matching
    content_type.include?('json') ? :json : nil 
  end
end
```

See below if you're using the `media_types` gem.

### Deserializer lookup

If you _don't_ provide the `lookup_deserializer_by_symbol` configuration, it currently can only deserialize `json` and
will only do so if the symbol is `:json`, requiring `oj`. If you don't want this behaviour, define it.

```ruby
MediaTypes::Deserialization.configure do
  self.lookup_deserializer_by_symbol = lambda do |symbol|
    case symbol
      when :json
        return CustomJsonDeserializer
      when :xml
      when :html
      when :xhtml
        return CustomXmlDeserializer
    else
      nil
    end
  end
end
```

### Media Type lookup and validation

If you *want* media type validation, for example via the `media_types` gem, provide the `lookup_media_type_by_symbol`
option and return the media types. The easiest way to accomplish this is tracking your registerables when you register
the media types, and creating a Lookup Map like so:

```ruby
# In some initializer that defines the media types,
#   given a module MyDomain::MediaTypes which holds many media types

require 'my_domain/media_types'
require 'media_types/integrations/actionpack'

registerables = []
MyDomain::MediaTypes.module_exec do
  registerables.concat self::Author.register
  registerables.concat self::Book.register
  registerables.concat self::Configuration.register
  registerables.concat self::Errors.register 
  registerables.concat self::Signature.register
  
  # Create lookup table by string (content-type) => media type
  lookup = registerables.flatten.each_with_object({}) do |registerable, hash|
    [registerable.media_type, *registerable.aliases].each do |type|
      hash[String(type)] = registerable
    end
  end.freeze
    
  # Create lookup table by symbol => media_type
  lookup_by_symbol = registerables.flatten.each_with_object({}) do |registerable, hash|
    hash[String(registerable.symbol).to_sym] = registerable
  end.freeze
    
  const_set(:LOOKUP, lookup)
  const_set(:LOOKUP_BY_SYMBOL, lookup_by_symbol)
end 
```

At this point you can re-use those lookup tables for both the media type lookup and the symbol lookup:

```ruby
MediaTypes::Deserialization.configure do
  self.lookup_content_type_symbol = lambda do |content_type|
    registerable = MyDomain::MediaTypes.const_get(:Lookup).fetch(content_type) { nil }
    registerable&.symbol
  end
  
  self.lookup_media_type_by_symbol = lambda do |symbol|
    registerable = MyDomain::MediaTypes.const_get(:LOOKUP_BY_SYMBOL).fetch(symbol) { nil }
    registerable&.media_type
  end
end
```

### Related

- [`MediaTypes`](https://github.com/SleeplessByte/media-types-ruby): :gem: Library to create media type definitions, schemes and validations
- [`MediaTypes::Serialization`](https://github.com/XPBytes/media_types-serialization): :cyclone: Add media types supported serialization using your favourite serializer
- [`MediaTypes::Validation`](https://github.com/XPBytes/media_types-validation): :heavy_exclamation_mark: Response validations according to a media-type

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can
also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the
version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at [XPBytes/media_types-deserialization](https://github.com/XPBytes/media_types-deserialization).
