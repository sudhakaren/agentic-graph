import SwiftUI

// MARK: - Bezier Sampling

struct EdgeGeometry {

    /// Sample a cubic bezier curve into a polyline
    static func sampleBezier(from: CGPoint, to: CGPoint, segments: Int = 20) -> [CGPoint] {
        let cp1 = CGPoint(x: (from.x + to.x) / 2, y: from.y)
        let cp2 = CGPoint(x: (from.x + to.x) / 2, y: to.y)
        var points: [CGPoint] = []
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let it = 1 - t
            let x = it*it*it * from.x + 3*it*it*t * cp1.x + 3*it*t*t * cp2.x + t*t*t * to.x
            let y = it*it*it * from.y + 3*it*it*t * cp1.y + 3*it*t*t * cp2.y + t*t*t * to.y
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }

    /// Find intersection point of two line segments, returns (point, tOnA)
    static func segmentIntersection(
        a1: CGPoint, a2: CGPoint,
        b1: CGPoint, b2: CGPoint
    ) -> (point: CGPoint, t: CGFloat)? {
        let d1 = CGPoint(x: a2.x - a1.x, y: a2.y - a1.y)
        let d2 = CGPoint(x: b2.x - b1.x, y: b2.y - b1.y)
        let cross = d1.x * d2.y - d1.y * d2.x
        guard abs(cross) > 1e-10 else { return nil }

        let t = ((b1.x - a1.x) * d2.y - (b1.y - a1.y) * d2.x) / cross
        let u = ((b1.x - a1.x) * d1.y - (b1.y - a1.y) * d1.x) / cross

        guard (0.001...0.999).contains(t), (0.001...0.999).contains(u) else { return nil }

        let point = CGPoint(x: a1.x + t * d1.x, y: a1.y + t * d1.y)
        return (point, t)
    }

    /// Find all intersection points of polyline A with polyline B
    /// Returns intersections sorted by parametric position along A
    static func findIntersections(
        polyA: [CGPoint],
        polyB: [CGPoint]
    ) -> [(point: CGPoint, t: CGFloat, crossAngle: CGFloat)] {
        var results: [(point: CGPoint, t: CGFloat, crossAngle: CGFloat)] = []
        let segCountA = polyA.count - 1
        let segCountB = polyB.count - 1
        guard segCountA > 0, segCountB > 0 else { return results }

        for i in 0..<segCountA {
            for j in 0..<segCountB {
                if let hit = segmentIntersection(
                    a1: polyA[i], a2: polyA[i + 1],
                    b1: polyB[j], b2: polyB[j + 1]
                ) {
                    let globalT = (CGFloat(i) + hit.t) / CGFloat(segCountA)
                    // Angle of the crossing segment (B)
                    let dx = polyB[j + 1].x - polyB[j].x
                    let dy = polyB[j + 1].y - polyB[j].y
                    let angle = atan2(dy, dx)
                    results.append((hit.point, globalT, angle))
                }
            }
        }
        return results.sorted { $0.t < $1.t }
    }

    /// Build a bezier path with hop-over arcs at intersection points
    static func buildBezierPath(
        from: CGPoint,
        to: CGPoint,
        hopOvers: [(point: CGPoint, t: CGFloat, crossAngle: CGFloat)]
    ) -> (path: CGMutablePath, points: [CGPoint]) {
        let path = CGMutablePath()
        let points = sampleBezier(from: from, to: to)
        let hopRadius: CGFloat = 8

        guard !points.isEmpty else { return (path, points) }
        path.move(to: points[0])

        if hopOvers.isEmpty {
            // Simple cubic bezier
            let cp1 = CGPoint(x: (from.x + to.x) / 2, y: from.y)
            let cp2 = CGPoint(x: (from.x + to.x) / 2, y: to.y)
            path.addCurve(to: to, control1: cp1, control2: cp2)
            return (path, points)
        }

        // Walk through sampled points, inserting arcs at hops
        let segCount = points.count - 1
        var hopIndex = 0

        for i in 0..<segCount {
            let segTStart = CGFloat(i) / CGFloat(segCount)
            let segTEnd = CGFloat(i + 1) / CGFloat(segCount)

            // Check if any hop falls in this segment
            while hopIndex < hopOvers.count &&
                  hopOvers[hopIndex].t >= segTStart &&
                  hopOvers[hopIndex].t < segTEnd {

                let hop = hopOvers[hopIndex]

                // Direction perpendicular to crossing edge (always hop "up")
                let perpAngle = hop.crossAngle + .pi / 2
                let arcCenter = CGPoint(
                    x: hop.point.x + cos(perpAngle) * hopRadius,
                    y: hop.point.y + sin(perpAngle) * hopRadius
                )

                // Draw line to approach point, then arc, then continue
                let approachAngle = perpAngle + .pi
                let approach = CGPoint(
                    x: arcCenter.x + cos(approachAngle - .pi / 2) * hopRadius,
                    y: arcCenter.y + sin(approachAngle - .pi / 2) * hopRadius
                )
                path.addLine(to: approach)
                path.addArc(
                    center: arcCenter,
                    radius: hopRadius,
                    startAngle: approachAngle,
                    endAngle: approachAngle + .pi,
                    clockwise: false
                )

                hopIndex += 1
            }

            path.addLine(to: points[i + 1])
        }

        return (path, points)
    }
}
