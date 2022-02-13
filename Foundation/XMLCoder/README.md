# XMLCoder

Encoder &amp; Decoder for XML using Swift's `Codable` protocols.

[![Build Status](https://dev.azure.com/max0484/max/_apis/build/status/MaxDesiatov.XMLCoder?branchName=main)](https://dev.azure.com/max0484/max/_build/latest?definitionId=4&branchName=main)
[![Version](https://img.shields.io/cocoapods/v/XMLCoder.svg?style=flat)](https://cocoapods.org/pods/XMLCoder)
[![License](https://img.shields.io/cocoapods/l/XMLCoder.svg?style=flat)](https://cocoapods.org/pods/XMLCoder)
[![Platform](https://img.shields.io/badge/platform-watchos%20%7C%20ios%20%7C%20tvos%20%7C%20macos%20%7C%20linux%20%7C%20windows-lightgrey.svg?style=flat)](https://cocoapods.org/pods/XMLCoder)
[![Coverage](https://img.shields.io/codecov/c/github/MaxDesiatov/XMLCoder/main.svg?style=flat)](https://codecov.io/gh/maxdesiatov/XMLCoder)

This package is a fork of the original
[ShawnMoore/XMLParsing](https://github.com/ShawnMoore/XMLParsing)
with more features and improved test coverage. Automatically generated documentation is available on [our GitHub Pages](https://maxdesiatov.github.io/XMLCoder/).

## Example

```swift
import XMLCoder
import Foundation

let sourceXML = """
<note>
    <to>Bob</to>
    <from>Jane</from>
    <heading>Reminder</heading>
    <body>Don't forget to use XMLCoder!</body>
</note>
"""

struct Note: Codable {
    let to: String
    let from: String
    let heading: String
    let body: String
}

let note = try! XMLDecoder().decode(Note.self, from: Data(sourceXML.utf8))

let encodedXML = try! XMLEncoder().encode(note, withRootKey: "note")
```

## Advanced features

The following features are available in [0.4.0
release](https://github.com/MaxDesiatov/XMLCoder/releases/tag/0.4.0) or later
(unless stated otherwise):

### Stripping namespace prefix

Sometimes you need to handle an XML namespace prefix, like in the XML below:

```xml
<h:table xmlns:h="http://www.w3.org/TR/html4/">
  <h:tr>
    <h:td>Apples</h:td>
    <h:td>Bananas</h:td>
  </h:tr>
</h:table>
```

Stripping the prefix from element names is enabled with
`shouldProcessNamespaces` property:

```swift
struct Table: Codable, Equatable {
    struct TR: Codable, Equatable {
        let td: [String]
    }

    let tr: [TR]
}


let decoder = XMLDecoder()

// Setting this property to `true` for the namespace prefix to be stripped
// during decoding so that key names could match.
decoder.shouldProcessNamespaces = true

let decoded = try decoder.decode(Table.self, from: xmlData)
```

### Dynamic node coding

XMLCoder provides two helper protocols that allow you to customize whether nodes
are encoded and decoded as attributes or elements: `DynamicNodeEncoding` and
`DynamicNodeDecoding`.

The declarations of the protocols are very simple:

```swift
protocol DynamicNodeEncoding: Encodable {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding
}

protocol DynamicNodeDecoding: Decodable {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding
}
```

The values returned by corresponding `static` functions look like this:

```swift
enum NodeDecoding {
    // decodes a value from an attribute
    case attribute

    // decodes a value from an element
    case element

    // the default, attempts to decode as an element first,
    // otherwise reads from an attribute
    case elementOrAttribute
}

enum NodeEncoding {
    // encodes a value in an attribute
    case attribute

    // the default, encodes a value in an element
    case element

    // encodes a value in both attribute and element
    case both
}
```

Add conformance to an appropriate protocol for types you'd like to customize.
Accordingly, this example code:

```swift
struct Book: Codable, Equatable, DynamicNodeEncoding {
    let id: UInt
    let title: String
    let categories: [Category]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case categories = "category"
    }

    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key {
        case Book.CodingKeys.id: return .both
        default: return .element
        }
    }
}
```

works for this XML:

```xml
<book id="123">
    <id>123</id>
    <title>Cat in the Hat</title>
    <category>Kids</category>
    <category>Wildlife</category>
</book>
```

Please refer to PR [\#70](https://github.com/MaxDesiatov/XMLCoder/pull/70) by
[@JoeMatt](https://github.com/JoeMatt) for more details.

### Coding key value intrinsic

Suppose that you need to decode an XML that looks similar to this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<foo id="123">456</foo>
```

By default you'd be able to decode `foo` as an element, but then it's not
possible to decode the `id` attribute. `XMLCoder` handles certain `CodingKey`
values in a special way to allow proper coding for this XML. Just add a coding
key with `stringValue` that equals `""` (empty string). What
follows is an example type declaration that encodes the XML above, but special
handling of coding keys with those values works for both encoding and decoding.

```swift
struct Foo: Codable, DynamicNodeEncoding {
    let id: String
    let value: String

    enum CodingKeys: String, CodingKey {
        case id
        case value = ""
    }

    static func nodeEncoding(forKey key: CodingKey)
    -> XMLEncoder.NodeEncoding {
        switch key {
        case CodingKeys.id:
            return .attribute
        default:
            return .element
        }
    }
}
```

Thanks to [@JoeMatt](https://github.com/JoeMatt) for implementing this in
in PR [\#73](https://github.com/MaxDesiatov/XMLCoder/pull/73).

### Preserving whitespaces in element content

By default whitespaces are trimmed in element content during decoding. This
includes string values decoded with [value intrinsic keys](#coding-key-value-intrinsic).
Starting with [version 0.5](https://github.com/MaxDesiatov/XMLCoder/releases/tag/0.5.0)
you can now set a property `trimValueWhitespaces` to `false` (the default value is `true`) on
`XMLDecoder` instance to preserve all whitespaces in decoded strings.


### Remove whitespace elements

When decoding pretty-printed XML while `trimValueWhitespaces` is set to `false`, it's possible
for whitespace elements to be added as child elements on an instance of `XMLCoderElement`.  These
whitespace elements make it impossible to decode data structures that require custom `Decodable` logic.
Starting with [version 0.13.0](https://github.com/MaxDesiatov/XMLCoder/releases/tag/0.13.0) you can
set a property `removeWhitespaceElements` to `true` (the default value is `false`) on
`XMLDecoder` to remove these whitespace elements.

### Choice element coding

Starting with [version 0.8](https://github.com/MaxDesiatov/XMLCoder/releases/tag/0.8.0),
you can encode and decode `enum`s with associated values by conforming your
`CodingKey` type additionally to `XMLChoiceCodingKey`. This allows decoding
XML elements similar in structure to this example:

```xml
<container>
    <int>1</int>
    <string>two</string>
    <string>three</string>
    <int>4</int>
    <int>5</int>
</container>
```

To decode these elements you can use this type:

```swift
enum IntOrString: Equatable {
    case int(Int)
    case string(String)
}

extension IntOrString: Codable {
    enum CodingKeys: String, XMLChoiceCodingKey {
        case int
        case string
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .int(value):
            try container.encode(value, forKey: .int)
        case let .string(value):
            try container.encode(value, forKey: .string)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            self = .int(try container.decode(Int.self, forKey: .int))
        } catch {
            self = .string(try container.decode(String.self, forKey: .string))
        }
    }
}
```

This is described in more details in PR [\#119](https://github.com/MaxDesiatov/XMLCoder/pull/119)
by [@jsbean](https://github.com/jsbean) and [@bwetherfield](https://github.com/bwetherfield).

### Integrating with [Combine](https://developer.apple.com/documentation/combine)

Starting with XMLCoder [version 0.9](https://github.com/MaxDesiatov/XMLCoder/releases/tag/0.9.0),
when Apple's Combine framework is available, `XMLDecoder` conforms to the
`TopLevelDecoder` protocol, which allows it to be used with the
`decode(type:decoder:)` operator:

```swift
import Combine
import Foundation
import XMLCoder

func fetchBook(from url: URL) -> AnyPublisher<Book, Error> {
    return URLSession.shared.dataTaskPublisher(for: url)
        .map(\.data)
        .decode(type: Book.self, decoder: XMLDecoder())
        .eraseToAnyPublisher()
}
```

This was implemented in PR [\#132](https://github.com/MaxDesiatov/XMLCoder/pull/132)
by [@sharplet](https://github.com/sharplet).

Additionally, starting with [XMLCoder
0.11](https://github.com/MaxDesiatov/XMLCoder/releases/tag/0.11.0) `XMLEncoder`
conforms to the `TopLevelEncoder` protocol:

```swift
import Combine
import XMLCoder

func encode(book: Book) -> AnyPublisher<Data, Error> {
    return Just(book)
        .encode(encoder: XMLEncoder())
        .eraseToAnyPublisher()
}
```

The resulting XML in the example above will start with `<book`, to customize
capitalization of the root element (e.g. `<Book`) you'll need to set an
appropriate `keyEncoding` strategy on the encoder. To change the element name
altogether you'll have to change the name of the type, which is an unfortunate
limitation of the `TopLevelEncoder` API.

### Root element attributes

Sometimes you need to set attributes on the root element, which aren't
directly related to your model type. Starting with [XMLCoder
0.11](https://github.com/MaxDesiatov/XMLCoder/releases/tag/0.11.0) the `encode`
function on `XMLEncoder` accepts a new `rootAttributes` argument to help with
this:

```swift
struct Policy: Encodable {
    var name: String
}

let encoder = XMLEncoder()
let data = try encoder.encode(Policy(name: "test"), rootAttributes: [
    "xmlns": "http://www.nrf-arts.org/IXRetail/namespace",
    "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
    "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
])
```

The resulting XML will look like this:

```xml
<policy xmlns="http://www.nrf-arts.org/IXRetail/namespace"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <name>test</name>
</policy>
```

This was implemented in PR [\#160](https://github.com/MaxDesiatov/XMLCoder/pull/160)
by [@portellaa](https://github.com/portellaa).

## Installation

### Requirements

**Apple Platforms**

- Xcode 11.0 or later
  - **IMPORTANT**: compiling XMLCoder with Xcode 11.2.0 (11B52) and 11.2.1 (11B500) is not recommended due to crashes with `EXC_BAD_ACCESS` caused by [a compiler bug](https://bugs.swift.org/browse/SR-11564), please use Xcode 11.3 or later instead. Please refer to [\#150](https://github.com/MaxDesiatov/XMLCoder/issues/150) for more details.
- Swift 5.1 or later
- iOS 9.0 / watchOS 2.0 / tvOS 9.0 / macOS 10.10 or later deployment targets

**Linux**

- Ubuntu 18.04 or later
- Swift 5.1 or later

**Windows**

- Swift 5.5 or later.

### Swift Package Manager

[Swift Package Manager](https://swift.org/package-manager/) is a tool for
managing the distribution of Swift code. It’s integrated with the Swift build
system to automate the process of downloading, compiling, and linking
dependencies on all platforms.

Once you have your Swift package set up, adding `XMLCoder` as a dependency is as
easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/MaxDesiatov/XMLCoder.git", from: "0.13.1")
]
```

If you're using XMLCoder in an app built with Xcode, you can also add it as a direct
dependency [using Xcode's
GUI](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app).

### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Swift and Objective-C
Cocoa projects for Apple's platfoms. You can install it with the following command:

```bash
$ gem install cocoapods
```

Navigate to the project directory and create `Podfile` with the following command:

```bash
$ pod install
```

Inside of your `Podfile`, specify the `XMLCoder` pod:

```ruby
# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'YourApp' do
  # Comment the next line if you're not using Swift or don't want
  # to use dynamic frameworks
  use_frameworks!

  # Pods for YourApp
  pod 'XMLCoder', '~> 0.13.1'
end
```

Then, run the following command:

```bash
$ pod install
```

Open the the `YourApp.xcworkspace` file that was created. This should be the
file you use everyday to create your app, instead of the `YourApp.xcodeproj`
file.

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a dependency manager for Apple's
platfoms that builds your dependencies and provides you with binary frameworks.

Carthage can be installed with [Homebrew](https://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

Inside of your `Cartfile`, add GitHub path to `XMLCoder`:

```ogdl
github "MaxDesiatov/XMLCoder" ~> 0.13.1
```

Then, run the following command to build the framework:

```bash
$ carthage update
```

Drag the built framework into your Xcode project.

## Contributing

This project adheres to the [Contributor Covenant Code of
Conduct](https://github.com/MaxDesiatov/XMLCoder/blob/main/CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code. Please report
unacceptable behavior to xmlcoder@desiatov.com.

### Sponsorship

If this library saved you any amount of time or money, please consider [sponsoring
the work of its maintainer](https://github.com/sponsors/MaxDesiatov). While some of the
sponsorship tiers give you priority support or even consulting time, any amount is
appreciated and helps in maintaining the project.

### Coding Style

This project uses [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)
and [SwiftLint](https://github.com/realm/SwiftLint) to
enforce formatting and coding style. We encourage you to run SwiftFormat within
a local clone of the repository in whatever way works best for you either
manually or automatically via an [Xcode
extension](https://github.com/nicklockwood/SwiftFormat#xcode-source-editor-extension),
[build phase](https://github.com/nicklockwood/SwiftFormat#xcode-build-phase) or
[git pre-commit
hook](https://github.com/nicklockwood/SwiftFormat#git-pre-commit-hook) etc.

To guarantee that these tools run before you commit your changes on macOS, you're encouraged
to run this once to set up the [pre-commit](https://pre-commit.com/) hook:

```
brew bundle # installs SwiftLint, SwiftFormat and pre-commit
pre-commit install # installs pre-commit hook to run checks before you commit
```

Refer to [the pre-commit documentation page](https://pre-commit.com/) for more details
and installation instructions for other platforms.

SwiftFormat and SwiftLint also run on CI for every PR and thus a CI build can
fail with incosistent formatting or style. We require CI builds to pass for all
PRs before merging.

### Test Coverage

Our goal is to keep XMLCoder stable and to serialize any XML correctly according
to [XML 1.0 standard](https://www.w3.org/TR/2008/REC-xml-20081126/). All of this
can be easily tested automatically and we're slowly improving [test coverage of
XMLCoder](https://codecov.io/gh/MaxDesiatov/XMLCoder) and don't expect it to
decrease. PRs that decrease the test coverage have a much lower chance of being
merged. If you add any new features, please make sure to add tests, likewise for
changes and any refactoring in existing code.
