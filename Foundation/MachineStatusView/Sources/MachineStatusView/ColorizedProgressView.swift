//
//  ColorizedProgressView.swift
//
//
//  Created by Lakr Aream on 2022/3/3.
//

import SwiftUI

public struct ColorizedProgressView: View {
    struct ColorInfo: Identifiable, Equatable {
        var id: Color { color }
        let color: Color
        let weight: Float
    }

    let elements: [ColorInfo]
    let reservedWeight: Float
    let height: Float
    let backgroundColor: Color
    let rounded: Bool

    init(
        colors: [ColorInfo],
        reservedWeight: Float = 0,
        height: Float = 8,
        backgroundColor: Color = .black.opacity(0.1),
        rounded: Bool = true
    ) {
        elements = colors
        self.reservedWeight = reservedWeight
        self.height = height
        self.backgroundColor = backgroundColor
        self.rounded = rounded
    }

    var totalWeight: Float {
        elements.map(\.weight).reduce(0, +)
            + reservedWeight
    }

    @State var contentSize: CGSize = .init()

    public var body: some View {
        GeometryReader { reader in
            HStack(spacing: 0) {
                ForEach(0 ..< elements.count, id: \.self) { idx in
                    elements[idx]
                        .color
                        .frame(width: size(for: idx))
                }
                Spacer()
                    .frame(minWidth: 0, minHeight: 0)
            }
            .onAppear { contentSize = reader.size }
            .onChange(of: reader.size) { newValue in
                contentSize = newValue
            }
        }
        .animation(.spring(response: 0.25), value: elements)
        .background(backgroundColor)
        .frame(height: CGFloat(exactly: height) ?? 0)
        .cornerRadius(rounded ? (CGFloat(exactly: height) ?? 0) / 2 : 0)
    }

    func size(for index: Int) -> CGFloat {
        let weight = elements[index].weight / totalWeight
        if weight < 0 { return 0 }
        return (CGFloat(exactly: weight) ?? 0) * contentSize.width
    }
}
