//
//  HostWindow.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/11.
//

import SwiftUI

class WindowObserver: ObservableObject {
    weak var window: Window?
}

// https://lostmoa.com/blog/ReadingTheCurrentWindowInANewSwiftUILifecycleApp/

// extension EnvironmentValues {
//    struct IsKeyWindowKey: EnvironmentKey {
//        static var defaultValue: Bool = false
//        typealias Value = Bool
//    }
//
//    fileprivate(set) var isKeyWindow: Bool {
//        get {
//            self[IsKeyWindowKey.self]
//        }
//        set {
//            self[IsKeyWindowKey.self] = newValue
//        }
//    }
// }

#if canImport(UIKit)
    typealias Window = UIWindow
#elseif canImport(AppKit)
    typealias Window = NSWindow
#else
    #error("Unsupported platform")
#endif

#if canImport(UIKit)
    struct HostingWindowFinder: UIViewRepresentable {
        var callback: (Window?) -> Void

        func makeUIView(context _: Context) -> UIView {
            let view = UIView()
            DispatchQueue.main.async { [weak view] in
                self.callback(view?.window)
            }
            return view
        }

        func updateUIView(_: UIView, context _: Context) {}
    }

#elseif canImport(AppKit)
    struct HostingWindowFinder: NSViewRepresentable {
        var callback: (Window?) -> Void

        func makeNSView(context _: Self.Context) -> NSView {
            let view = NSView()
            DispatchQueue.main.async { [weak view] in
                self.callback(view?.window)
            }
            return view
        }

        func updateNSView(_: NSView, context _: Context) {}
    }
#else
    #error("Unsupported platform")
#endif
