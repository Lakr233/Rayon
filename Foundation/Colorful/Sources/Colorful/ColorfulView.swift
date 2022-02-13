//
//  ColorfulView.swift
//  Colorful
//
//  Created by Lakr Aream on 2021/9/19.
//

import SwiftUI

public struct ColorfulView: View {
    // MARK: - PROPERTY

    @State var randomization: [PointRandomization]
    @State var size: CGSize = CGSize()

    private let colorElements: [Color]
    private let animated: Bool
    private let animation: Animation
    private let blurRadius: CGFloat

    private let timer = Timer
        .publish(every: 5, on: .main, in: .common)
        .autoconnect()

    // MARK: - INIT

    public init(
        animated: Bool = defaultAnimated,
        animation: Animation = defaultAnimation,
        blurRadius: CGFloat = defaultBlurRadius,
        colors: [Color] = defaultColorList,
        colorCount: Int = defaultColorCount
    ) {
        assert(colors.count > 0)
        assert(colorCount > 0)
        assert(blurRadius > 0)

        self.animated = animated
        self.animation = animation
        self.blurRadius = blurRadius

        var colorCompiler = [Color]()
        while colorCompiler.count < colorCount {
            colorCompiler.append(contentsOf: colors.shuffled())
        }
        if colorCompiler.count > colorCount {
            colorCompiler.removeLast(colorCompiler.count - colorCount)
        }
        assert(colorCompiler.count == colorCount)
        colorElements = colorCompiler

        _randomization = State(initialValue: [PointRandomization](repeating: .init(), count: colorCount))
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        public init(
            animated: Bool = defaultAnimated,
            animation: Animation = defaultAnimation,
            blurRadius: CGFloat = defaultBlurRadius,
            nsColors: [NSColor],
            colorCount: Int = defaultColorCount
        ) {
            self.init(
                animated: animated,
                animation: animation,
                blurRadius: blurRadius,
                colors: nsColors.map { Color($0) },
                colorCount: colorCount
            )
        }
    #endif

    #if canImport(UIKit)
        public init(
            animated: Bool = defaultAnimated,
            animation: Animation = defaultAnimation,
            blurRadius: CGFloat = defaultBlurRadius,
            uiColors: [UIColor],
            colorCount: Int = defaultColorCount
        ) {
            self.init(
                animated: animated,
                animation: animation,
                blurRadius: blurRadius,
                colors: uiColors.map { Color($0) },
                colorCount: colorCount
            )
        }
    #endif

    // MARK: - VIEW

    public var body: some View {
        GeometryReader { reader in
            ZStack {
                ForEach(obtainRangeAndUpdate(size: reader.size), id: \.self) { idx in
                    Circle()
                        .foregroundColor(colorElements[idx])
                        .opacity(0.5)
                        .frame(width: randomization[idx].diameter,
                               height: randomization[idx].diameter)
                        .offset(x: randomization[idx].offsetX,
                                y: randomization[idx].offsetY)
                }
            }
            .frame(width: reader.size.width,
                   height: reader.size.height)
        }
        .clipped()
        .blur(radius: blurRadius)
        .onReceive(timer) { _ in
            dispatchUpdate()
        }
    }

    // MARK: - FUNCTION

    private func dispatchUpdate() {
        if !animated { return }
        withAnimation(animation) {
            randomizationStart()
        }
    }

    private func randomizationStart() {
        var randomizationBuilder = [PointRandomization]()
        while randomizationBuilder.count < randomization.count {
            let randomizationElement: PointRandomization = {
                var randomization = PointRandomization()
                randomization.randomizeIn(size: size)
                return randomization
            }()
            randomizationBuilder.append(randomizationElement)
        }
        randomization = randomizationBuilder
    }

    private func obtainRangeAndUpdate(size: CGSize) -> Range<Int> {
        issueSizeUpdate(withValue: size)
        return 0 ..< colorElements.count
    }

    private func issueSizeUpdate(withValue size: CGSize) {
        if self.size == size { return }
        DispatchQueue.main.async {
            self.size = size
            self.dispatchUpdate()
        }
    }
}
