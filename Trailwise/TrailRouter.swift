import Foundation

enum TrailRouter {
    struct Plan {
        var points: [TrailCoordinate]
        var snappedSegmentCount: Int
        var segmentCount: Int
    }

    private struct Edge {
        var destination: String
        var meters: Double
    }

    private struct QueueEntry {
        var node: String
        var distance: Double
    }

    static func plan(through waypoints: [TrailCoordinate], trails: [OutdoorFeature]) -> Plan {
        guard !waypoints.isEmpty else { return Plan(points: [], snappedSegmentCount: 0, segmentCount: 0) }
        let graph = makeGraph(trails)
        guard !graph.coordinates.isEmpty else {
            return Plan(points: waypoints, snappedSegmentCount: 0, segmentCount: max(0, waypoints.count - 1))
        }

        let anchors = waypoints.map { nearestNode(to: $0, graph: graph) }
        var output: [TrailCoordinate] = [waypoints[0]]
        var snapped = 0
        for index in 1..<waypoints.count {
            let start = anchors[index - 1]
            let end = anchors[index]
            if let start, let end,
               start.distance <= 150, end.distance <= 150,
               let trailPath = shortestPath(from: start.key, to: end.key, graph: graph) {
                appendUnique(trailPath.map { graph.coordinates[$0]! }, to: &output)
                snapped += 1
            }
            appendUnique([waypoints[index]], to: &output)
        }
        return Plan(points: output, snappedSegmentCount: snapped, segmentCount: max(0, waypoints.count - 1))
    }

    private struct Graph {
        var coordinates: [String: TrailCoordinate] = [:]
        var edges: [String: [Edge]] = [:]
    }

    private static func makeGraph(_ trails: [OutdoorFeature]) -> Graph {
        var graph = Graph()
        for trail in trails where trail.path.count > 1 {
            for point in trail.path { graph.coordinates[key(for: point)] = point }
            for (a, b) in zip(trail.path, trail.path.dropFirst()) {
                let first = key(for: a)
                let second = key(for: b)
                let distance = a.distance(to: b)
                guard distance > 0 else { continue }
                graph.edges[first, default: []].append(Edge(destination: second, meters: distance))
                graph.edges[second, default: []].append(Edge(destination: first, meters: distance))
            }
        }
        return graph
    }

    private static func key(for point: TrailCoordinate) -> String {
        String(format: "%.6f,%.6f", point.latitude, point.longitude)
    }

    private static func nearestNode(to point: TrailCoordinate, graph: Graph) -> (key: String, distance: Double)? {
        graph.coordinates.min { point.distance(to: $0.value) < point.distance(to: $1.value) }
            .map { (key: $0.key, distance: point.distance(to: $0.value)) }
    }

    private static func shortestPath(from start: String, to end: String, graph: Graph) -> [String]? {
        if start == end { return [start] }
        var distances = [start: 0.0]
        var previous: [String: String] = [:]
        var queue = [QueueEntry(node: start, distance: 0)]

        while !queue.isEmpty {
            queue.sort { $0.distance > $1.distance }
            let current = queue.removeLast()
            guard current.distance <= distances[current.node, default: .infinity] else { continue }
            if current.node == end { break }

            for edge in graph.edges[current.node, default: []] {
                let candidate = current.distance + edge.meters
                if candidate < distances[edge.destination, default: .infinity] {
                    distances[edge.destination] = candidate
                    previous[edge.destination] = current.node
                    queue.append(QueueEntry(node: edge.destination, distance: candidate))
                }
            }
        }

        guard distances[end] != nil else { return nil }
        var path = [end]
        var cursor = end
        while let parent = previous[cursor] {
            path.append(parent)
            cursor = parent
            if cursor == start { break }
        }
        return path.last == start ? Array(path.reversed()) : nil
    }

    private static func appendUnique(_ points: [TrailCoordinate], to output: inout [TrailCoordinate]) {
        for point in points {
            if let last = output.last, last.distance(to: point) < 0.5 { continue }
            output.append(point)
        }
    }
}

