//
//  PointRandomization.swift
//  Colorful
//
//  Created by Lakr Aream on 2021/9/19.
//

import SwiftUI

extension ColorfulView {
    struct PointRandomization: Equatable, Hashable, Identifiable {
        var id = UUID()

        var diameter: CGFloat = 0
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0

        var color: Color = .white.opacity(0)

        mutating func randomizeIn(size: CGSize) {
            let decision = (size.width + size.height) / 4
            diameter = CGFloat.random(in: (decision * 0.25) ... (decision * 0.75))
            offsetX = CGFloat.random(in: -(size.width / 2) ... +(size.width / 2))
            offsetY = CGFloat.random(in: -(size.height / 2) ... +(size.height / 2))
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(diameter)
            hasher.combine(offsetX)
            hasher.combine(offsetY)
        }

        static func == (lhs: PointRandomization, rhs: PointRandomization) -> Bool {
            lhs.diameter == rhs.diameter &&
                lhs.offsetX == rhs.offsetX &&
                lhs.offsetY == rhs.offsetY
        }
    }
}
