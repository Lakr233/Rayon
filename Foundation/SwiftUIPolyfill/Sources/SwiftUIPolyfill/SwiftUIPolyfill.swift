import Foundation
import SwiftUI

// @available(iOS, introduced:14.0, obsoleted:15.0)
// @available(tvOS, unavailable)
// @available(watchOS, unavailable)
// public protocol TextSelectability {
//    static var allowsSelection: Bool { get }
// }
//
// @available(iOS, introduced:14.0, obsoleted:15.0)
// @available(tvOS, unavailable)
// @available(watchOS, unavailable)
// extension View {
//    public func textSelection<S>(_ selectability: S) -> some View where S : TextSelectability {
//        return self
//    }
// }

@available(iOS, introduced: 14.0, obsoleted: 15.0)
extension Date {
    public struct FormatStylePolyfill {
        /// The locale to use when formatting date and time values.
        public var date: Date.FormatStylePolyfill.DateStyle?

        public var time: Date.FormatStylePolyfill.TimeStyle?

        /// The locale to use when formatting date and time values.
        public var locale: Locale

        /// The time zone with which to specify date and time values.
        public var timeZone: TimeZone

        /// The calendar to use for date values.
        public var calendar: Calendar

        /// Creates a new `FormatStylePolyfill` with the given configurations.
        /// - Parameters:
        ///   - date:  The date style for formatting the date.
        ///   - time:  The time style for formatting the date.
        ///   - locale: The locale to use when formatting date and time values.
        ///   - calendar: The calendar to use for date values.
        ///   - timeZone: The time zone with which to specify date and time values.
        ///   - capitalizationContext: The capitalization formatting context used when formatting date and time values.
        /// - Note: Always specify the date length, time length, or the date components to be included in the formatted string with the symbol modifiers. Otherwise, an empty string will be returned when you use the instance to format a `Date`.
        public init(date: Date.FormatStylePolyfill.DateStyle? = nil, time: Date.FormatStylePolyfill.TimeStyle? = nil, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent, capitalizationContext _: Any? = nil) {
            self.date = date
            self.time = time
            self.locale = locale
            self.calendar = calendar
            self.timeZone = timeZone
        }
    }
}

@available(iOS, introduced: 14.0, obsoleted: 15.0)
extension Date.FormatStylePolyfill {
    /// Predefined date styles varied in lengths or the components included. The exact format depends on the locale.
    public struct DateStyle: Codable, Hashable {
        /// Excludes the date part.
        public static let omitted = Date.FormatStylePolyfill.DateStyle(style: "omitted")

        /// Shows date components in their numeric form. For example, "10/21/2015".
        public static let numeric = Date.FormatStylePolyfill.DateStyle(style: "numeric")

        /// Shows date components in their abbreviated form if possible. For example, "Oct 21, 2015".
        public static let abbreviated = Date.FormatStylePolyfill.DateStyle(style: "abbreviated")

        /// Shows date components in their long form if possible. For example, "October 21, 2015".
        public static let long = Date.FormatStylePolyfill.DateStyle(style: "long")

        /// Shows the complete day. For example, "Wednesday, October 21, 2015".
        public static let complete = Date.FormatStylePolyfill.DateStyle(style: "complete")

        public let style: String

        public init(style: String) {
            self.style = style
        }
    }

    /// Predefined time styles varied in lengths or the components included. The exact format depends on the locale.
    public struct TimeStyle: Codable, Hashable {
        /// Excludes the time part.
        public static let omitted = Date.FormatStylePolyfill.TimeStyle(style: "omitted")

        /// For example, `04:29 PM`, `16:29`.
        public static let shortened = Date.FormatStylePolyfill.TimeStyle(style: "shortened")

        /// For example, `4:29:24 PM`, `16:29:24`.
        public static let standard = Date.FormatStylePolyfill.TimeStyle(style: "standard")

        /// For example, `4:29:24 PM PDT`, `16:29:24 GMT`.
        public static let complete = Date.FormatStylePolyfill.TimeStyle(style: "complete")

        public let style: String

        public init(style: String) {
            self.style = style
        }
    }
}

@available(iOS, introduced: 14.0, obsoleted: 15.0)
extension Date {
    public func formatted() -> String {
        let formatter = DateFormatter()
        return formatter.string(from: self)
    }

    public func formatted(date: Date.FormatStylePolyfill.DateStyle, time: Date.FormatStylePolyfill.TimeStyle) -> String {
        let formatter = DateFormatter()
        switch date.style {
        case "complete":
            formatter.dateStyle = .full
        case "long":
            formatter.dateStyle = .long
        case "abbreviated":
            formatter.dateStyle = .medium
        case "numeric":
            formatter.dateStyle = .short
        case "omitted":
            formatter.dateStyle = .none
        default:
            formatter.dateStyle = .full
        }

        switch time.style {
        case "complete":
            formatter.timeStyle = .full
        case "standard":
            formatter.timeStyle = .medium
        case "shortened":
            formatter.timeStyle = .short
        case "omitted":
            formatter.timeStyle = .none
        default:
            formatter.timeStyle = .medium
        }
        return formatter.string(from: self)
    }
}

public struct CopyableText: View {
    @State var text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        if #available(iOS 15.0, *) {
            Text(self.text)
                .textSelection(.enabled)
        } else {
            Text(self.text)
                .contextMenu(ContextMenu(menuItems: {
                    Button("Copy", action: {
                        UIPasteboard.general.string = self.text
                    })
                }))
        }
    }
}

@available(iOS, introduced: 14.0, obsoleted: 15.0)
@available(macOS, unavailable)
public struct TextInputAutocapitalization {
    /// Defines an autocapitalizing behavior that will not capitalize anything.
    public static var never = TextInputAutocapitalization("never")

    /// Defines an autocapitalizing behavior that will capitalize the first
    /// letter of every word.
    public static var words = TextInputAutocapitalization("words")

    /// Defines an autocapitalizing behavior that will capitalize the first
    /// letter in every sentence.
    public static var sentences = TextInputAutocapitalization("sentences")

    /// Defines an autocapitalizing behavior that will capitalize every letter.
    public static var characters = TextInputAutocapitalization("characters")

    public var style: String
    public init(_ style: String) {
        self.style = style
    }
}

@available(iOS, introduced: 14.0, obsoleted: 15.0)
@available(macOS, unavailable)
extension View {
    public func textInputAutocapitalization(_ autocapitalization: TextInputAutocapitalization?) -> some View {
        let _style = autocapitalization?.style
        switch _style {
        case "never":
            return self.autocapitalization(.none)
        case "words":
            return self.autocapitalization(.words)
        case "sentences":
            return self.autocapitalization(.sentences)
        case "characters":
            return self.autocapitalization(.allCharacters)
        default:
            return self.autocapitalization(.sentences)
        }
    }
}

@available(iOS, introduced: 14.0, obsoleted: 15.0)
public struct InterfaceOrientation {
    public static let portrait = InterfaceOrientation()

    public static let portraitUpsideDown = InterfaceOrientation()

    public static let landscapeLeft = InterfaceOrientation()

    public static let landscapeRight = InterfaceOrientation()

    public init() {}
}

@available(iOS, introduced: 14.0, obsoleted: 15.0)
extension View {
    /// Overrides the orientation of the preview.
    ///
    /// By default, device previews appear right side up, using orientation
    /// ``InterfaceOrientation/portrait``. You can
    /// change the orientation of a preview using one of the values in
    /// the ``InterfaceOrientation`` structure:
    ///
    ///     struct CircleImage_Previews: PreviewProvider {
    ///         static var previews: some View {
    ///             CircleImage()
    ///                 .previewInterfaceOrientation(.landscapeRight)
    ///         }
    ///     }
    ///
    /// - Parameter value: An orientation to use for preview.
    /// - Returns: A preview that uses the given orientation.
    public func previewInterfaceOrientation(_: InterfaceOrientation) -> some View {
        self
    }
}

@available(iOS, introduced: 14.0, obsoleted: 15.0)
extension Section where Parent == Text, Content: View, Footer == EmptyView {
    public init<S>(_ title: S, @ViewBuilder content: () -> Content) where S: StringProtocol {
        self.init(content: content, header: {
            Text(title)
        })
    }
}

@available(iOS, introduced: 14.0, obsoleted: 15.0)
public struct SearchFieldPlacement {
    public static let automatic = SearchFieldPlacement()

    @available(tvOS, unavailable)
    public static let toolbar = SearchFieldPlacement()

    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public static let sidebar = SearchFieldPlacement()

    public init() {}
}

@available(iOS, introduced: 14.0, obsoleted: 15.0)
extension View {
    public func searchable(text _: Binding<String>, placement _: SearchFieldPlacement = .automatic, prompt _: Text? = nil) -> some View {
        self
    }
}

@available(iOS, introduced: 14.0, obsoleted: 15.0)
extension View {
    @inlinable public func overlay<V>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> some View where V: View {
        overlay(content(), alignment: alignment)
    }
}

@available(iOS, introduced: 14.0, obsoleted: 15.0)
extension PrimitiveButtonStyle {
    /// The default button style, based on the button's context.
    ///
    /// If you create a button directly on a blank canvas, the style varies by
    /// platform. iOS uses the borderless button style by default, whereas macOS,
    /// tvOS, and watchOS use the bordered button style.
    ///
    /// If you create a button inside a container, like a ``List``, the style
    /// resolves to the recommended style for buttons inside that container for
    /// that specific platform.
    ///
    /// You can override a button's style. To apply the default style to a
    /// button, or to a view that contains buttons, use the
    /// ``View/buttonStyle(_:)-66fbx`` modifier.
    public static var bordered: DefaultButtonStyle {
        DefaultButtonStyle.automatic
    }
}
