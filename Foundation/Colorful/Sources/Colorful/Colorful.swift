//
//  Colorful.swift
//
//
//  Created by Lakr Aream on 2021/9/19.
//

import SwiftUI

private let kDefaultSourceColorList = [#colorLiteral(red: 0.9586862922, green: 0.660125792, blue: 0.8447988033, alpha: 1), #colorLiteral(red: 0.8714533448, green: 0.723166883, blue: 0.9342088699, alpha: 1), #colorLiteral(red: 0.7458761334, green: 0.7851135731, blue: 0.9899476171, alpha: 1), #colorLiteral(red: 0.4398113191, green: 0.8953480721, blue: 0.9796616435, alpha: 1), #colorLiteral(red: 0.3484552801, green: 0.933657825, blue: 0.9058339596, alpha: 1), #colorLiteral(red: 0.5567936897, green: 0.9780793786, blue: 0.6893508434, alpha: 1)]

public extension ColorfulView {
    static let defaultAnimated: Bool = true
    static let defaultBlurRadius: CGFloat = 64
    static let defaultColorCount: Int = 32

    static let defaultAnimation: Animation = Animation
        .interpolatingSpring(stiffness: 50, damping: 1)
        .speed(0.05)

    static let defaultColorList: [Color] = kDefaultSourceColorList
        .map { Color($0) }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        static let defaultColorListNSColor: [NSColor] = kDefaultSourceColorList
    #endif

    #if canImport(UIKit)
        static let defaultColorListUIColor: [UIColor] = kDefaultSourceColorList
    #endif
}
