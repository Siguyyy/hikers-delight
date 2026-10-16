import SwiftUI

struct ElevationProfileView: View {
    var samples: [ElevationSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("ELEVATION PROFILE").font(.system(size: 9, weight: .bold)).tracking(0.6).foregroundStyle(.secondary)
                Spacer()
                Text("BY DISTANCE").font(.system(size: 9, weight: .medium)).tracking(0.3).foregroundStyle(.tertiary)
            }
            Canvas { context, size in
                guard samples.count > 1 else { return }
                let elevations = samples.map(\.elevationMeters)
                let low = elevations.min() ?? 0
                let high = elevations.max() ?? 1
                let spread = max(high - low, 1)
                let firstDistance = samples.first?.distanceMeters ?? 0
                let totalDistance = max((samples.last?.distanceMeters ?? 0) - firstDistance, 1)
                let inset: CGFloat = 5
                var line = Path()
                var fill = Path()
                for (index, sample) in samples.enumerated() {
                    let distanceFraction = (sample.distanceMeters - firstDistance) / totalDistance
                    let x = inset + CGFloat(distanceFraction) * (size.width - inset * 2)
                    let y = size.height - inset - CGFloat((sample.elevationMeters - low) / spread) * (size.height - inset * 2)
                    if index == 0 { line.move(to: CGPoint(x: x, y: y)); fill.move(to: CGPoint(x: x, y: size.height - inset)) }
                    line.addLine(to: CGPoint(x: x, y: y))
                    fill.addLine(to: CGPoint(x: x, y: y))
                }
                fill.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset))
                fill.closeSubpath()
                context.fill(fill, with: .linearGradient(Gradient(colors: [Color.green.opacity(0.28), Color.green.opacity(0.02)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                context.stroke(line, with: .color(Color(red: 0.18, green: 0.48, blue: 0.32)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            }
            HStack {
                Text("0 mi")
                Spacer()
                Text(String(format: "%.2f mi", (samples.last?.distanceMeters ?? 0) / 1609.344))
            }
            .font(.system(size: 9, weight: .medium).monospacedDigit())
            .foregroundStyle(.tertiary)
        }
    }
}
