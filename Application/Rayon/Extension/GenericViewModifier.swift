//
//  GenericViewModifier.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import SwiftUI

extension View {
    func expended() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func dropShadow() -> some View {
        shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 0)
    }

    func requiresFrame(_ width: Double = 500, _ height: Double = 250) -> some View {
        frame(minWidth: width, minHeight: height)
    }

    func requiresSheetFrame(_ width: Double = 450, _ height: Double = 200) -> some View {
        frame(minWidth: width, minHeight: height)
    }

    func makeHoverPointer() -> some View {
        #if os(macOS)
            onHover { inside in
                if inside {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        #else
            self
        #endif
    }

    func roundedCorner() -> some View {
        cornerRadius(8)
    }
}
