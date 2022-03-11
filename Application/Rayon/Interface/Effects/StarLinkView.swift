//
//  StarLinkView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import SwiftUI

private let starCount = 20
private let starAnimationDurationSecond: Double = 10
private let starEmitterSize: Double = 0
private let starSize: Double = 6
private let starSpeed: Double = 50
private let starCanvasWiggleLimit: Double = 25
private let starAnimation: Animation = Animation
    .interpolatingSpring(stiffness: 50, damping: 100)
    .speed(0.1)

struct StarLinkView: View {
    let timer = Timer
        .publish(every: 0.5, on: .main, in: .common)
        .autoconnect()

    let starFaith: [StarFaith] = {
        var newFaith = [StarFaith]()
        for _ in 0 ..< starCount {
            newFaith.append(.init(id: .init()))
        }
        return newFaith
    }()

    @State var shineOffsets: [ShineOffset] = []
    @State var canvasSize: CGSize = .init(width: 0, height: 0)
    @State var canvasWiggle: CGSize = .init(width: 0, height: 0)

    var body: some View {
        GeometryReader { r in
            ZStack {
                ForEach(shineOffsets) { faith in
                    ShineDotView()
                        .offset(x: faith.x, y: faith.y)
                        .opacity(faith.opacity)
                        .scaleEffect(faith.scale)
                }
            }
            .expended()
            .onChange(of: r.size) { newValue in
                if canvasSize != newValue { canvasSize = newValue }
            }
            .offset(x: canvasWiggle.width, y: canvasWiggle.height)
        }
        .onAppear { handleStarAnimation() }
        .onReceive(timer) { _ in handleStarAnimation() }
        .expended()
    }

    func handleStarAnimation() {
        if shineOffsets.isEmpty {
            bootstrapFaith()
            mainActor {
                handleStarAnimation()
            }
            return
        }
        animateWithOffset()
    }

    func bootstrapFaith() {
        var initialOffset = [ShineOffset]()
        for faith in starFaith {
            initialOffset.append(.init(
                id: faith.id,
                x: faith.currentPositionOffsetX,
                y: faith.currentPositionOffsetY,
                scale: 1.0,
                opacity: 0
            ))
        }
        shineOffsets = initialOffset
    }

    func animateWithOffset() {
        let original = shineOffsets
        var newArray = [ShineOffset]()
        for faith in starFaith {
            newArray.append(.init(
                id: faith.id,
                x: faith.currentPositionOffsetX,
                y: faith.currentPositionOffsetY,
                scale: Double.random(in: 1.0 ... 2.5),
                opacity: faith.opacity
            ))
        }
        var intermediateArray = original
        for i in 0 ..< newArray.count {
            if abs(original[i].x) < abs(newArray[i].x) {
                continue
            }
            if abs(original[i].y) < abs(newArray[i].y) {
                continue
            }
            // put it back
            intermediateArray[i] = newArray[i]
            // shine from nothing :P
            intermediateArray[i].opacity = 0
        }
        withAnimation(Animation.easeInOut(duration: 0.001)) {
            shineOffsets = intermediateArray
        }
        mainActor(delay: 0.1) {
            withAnimation(starAnimation) {
                shineOffsets = newArray
                canvasWiggle = CGSize(
                    width: .random(in: -starCanvasWiggleLimit ... starCanvasWiggleLimit),
                    height: .random(in: -starCanvasWiggleLimit ... starCanvasWiggleLimit)
                )
            }
        }
    }

    struct ShineOffset: Identifiable {
        var id: UUID
        var x: Double
        var y: Double
        var scale: Double
        var opacity: Double
    }

    struct StarFaith: Identifiable {
        var id: UUID

        init(id: UUID) {
            self.id = id
            beginData = Date(timeIntervalSinceNow:
                TimeInterval.random(in: -starAnimationDurationSecond ... 0)
            )
            radius = .random(in: 0 ... 2 * Double.pi)
            speed = .random(in: 100 ... 120)
        }

        let beginData: Date
        let radius: Double
        let speed: Double

        var deltaTime: Double {
            Date()
                .timeIntervalSince(beginData)
                .truncatingRemainder(dividingBy: starAnimationDurationSecond)
        }

        var speedParser: Double {
            let decision = cos(deltaTime / starAnimationDurationSecond * Double.pi / 2 * 0.5)
            if decision < 1 {
                return 1
            }
            return decision
        }

        var decisionOffset: Double {
            deltaTime * starSpeed * speedParser * 2 + 10
        }

        var currentPositionOffsetX: Double {
            cos(radius) * decisionOffset
        }

        var currentPositionOffsetY: Double {
            sin(radius) * decisionOffset
        }

        var opacity: Double {
            .random(in: 0.6 ... 1.0)
        }
    }

    struct ShineDotView: View {
        var body: some View {
            Circle()
                .foregroundColor(.accentColor)
                .frame(width: starSize, height: starSize)
        }
    }
}
