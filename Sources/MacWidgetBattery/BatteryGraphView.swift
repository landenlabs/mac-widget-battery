// Copyright (c) 2026 LanDen Labs - Dennis Lang
import SwiftUI

struct BatteryGraphView: View {
    let samples: [Double]   // values 0 – 100
    var color:   Color = .green

    var body: some View {
        Canvas { context, size in
            drawGrid(context: context, size: size)
            if samples.count > 1 {
                drawFill(context: context, size: size)
                drawLine(context: context, size: size)
            }
        }
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        for fraction in [0.25, 0.50, 0.75] {
            let y = size.height * CGFloat(1 - fraction)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(.white.opacity(0.08)),
                           style: StrokeStyle(lineWidth: 0.5))
        }
    }

    private func drawFill(context: GraphicsContext, size: CGSize) {
        let step = size.width / CGFloat(samples.count - 1)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        for (i, v) in samples.enumerated() {
            path.addLine(to: point(i, v, step, size))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        context.fill(path, with: .color(color.opacity(0.18)))
    }

    private func drawLine(context: GraphicsContext, size: CGSize) {
        let step = size.width / CGFloat(samples.count - 1)
        var path = Path()
        path.move(to: point(0, samples[0], step, size))
        for i in 1..<samples.count {
            path.addLine(to: point(i, samples[i], step, size))
        }
        context.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: 1.5))
    }

    private func point(_ i: Int, _ v: Double, _ step: CGFloat, _ size: CGSize) -> CGPoint {
        CGPoint(
            x: CGFloat(i) * step,
            y: size.height * CGFloat(1 - min(1, max(0, v / 100)))
        )
    }
}
