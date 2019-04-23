# Changelog

## 0.1.3

- 🚨 Update nokogiri: 1.10.2 → 1.10.3 (patch)
- Update oj: 3.7.10 → 3.7.12 (patch)
- Update all of rails: 5.2.2.1 → 5.2.3 (minor)
- Fix [`README.md`](./README.md) `require` statement

## 0.1.2

- Fix `ContentTypeNotRecognised` backtrace
- Fix issue when there is no content ánd no content-type (explicit nil)

## 0.1.1

- Fix error regarding `ContentTypeNotRecognised` (called as function instead of error class)
- Change `lookup_media_type_by_symbol` interface so that MediaTypes and Mime types can be mixed as return value

## 0.1.0

:baby: initial release
