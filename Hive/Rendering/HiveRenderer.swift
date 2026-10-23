import SpriteKit

/// Draws the hive at permanent visual tiers 1…11 (spec 5.5). Pure `SKShapeNode`s, origin at the hive centre.
///
/// Geometry: a true honeycomb of pointy-top hexes, circumradius `r`, neighbour distance `√3·r`.
/// Cells use axial coordinates `(q, s)` converted to pixels (SpriteKit, y up) as
/// `x = r·√3·(q + s/2)`, `y = r·1.5·s`, so axial `(1,0)` is east and `(0,1)` is north-east.
/// Ring `k` (6k cells) starts at the east cell `(k, 0)` and walks counter-clockwise, k steps along each
/// of the six directions starting with north-west. Ring index 0 is therefore east, and in ring `k` the
/// corners (east, NE, NW, west, SW, SE) sit at indices `0, k, 2k, …, 5k`.
///
/// The comb of rings 0…3 has a flat-top macro-hexagon silhouette (its corners point along the neighbour
/// directions), so the wax walls are flat-top hexagons concentric with it, sized to clear the full
/// ring-3 comb. Cells are crisp (`glowWidth 0`); the only glow is the ambient circle behind.
enum HiveRenderer {
    static let cellRadius: CGFloat = 13
    static let maxTier = 11

    /// Layer z order inside the hive node. Honey channels sit above the cells: cells are opaque and fill
    /// the comb with no gaps, so anything beneath them inside the comb would be invisible.
    private enum Z {
        static let glow: CGFloat = -2
        static let walls: CGFloat = -1
        static let cells: CGFloat = 0
        static let channels: CGFloat = 1
        static let queen: CGFloat = 2
        static let crown: CGFloat = 3
    }

    private static let directions: [(q: Int, s: Int)] = [(1, 0), (0, 1), (-1, 1), (-1, 0), (0, -1), (1, -1)]

    static func makeHive(visualTier: Int) -> SKNode {
        let tier = min(max(visualTier, 1), maxTier)
        let r = cellRadius
        let hive = SKNode()
        hive.name = "hive"

        hive.addChild(ambientGlow(tier: tier))

        // Cells.
        let cellAlpha: CGFloat = tier == 1 ? 0.75 : (tier == 2 ? 0.85 : 1)
        let queen = tier >= 10
        if !queen {
            hive.addChild(cell(at: .zero, color: Palette.gold, alpha: cellAlpha))
        }
        for k in 1...3 {
            for (i, hex) in ring(k).enumerated() where includes(ring: k, index: i, tier: tier) {
                hive.addChild(cell(at: pixel(hex), color: Palette.amber, alpha: cellAlpha))
            }
        }

        if tier >= innerWall.minTier {
            hive.addChild(wall(circumradius: innerWall.circumradius, color: Palette.burntOrange.withAlphaComponent(0.9),
                               width: innerWall.width))
        }
        if tier >= 8 {
            hive.addChild(honeyChannels())
        }
        if tier >= outerWall.minTier {
            hive.addChild(wall(circumradius: outerWall.circumradius, color: Palette.gold.withAlphaComponent(0.6),
                               width: outerWall.width))
        }
        if queen {
            hive.addChild(queenChamber())
        }
        if tier >= 11 {
            hive.addChild(crown())
        }
        return hive
    }

    /// Wall geometry shared by `makeHive` and `combRadius`.
    private static let innerWall = (circumradius: 6.8 * cellRadius, width: CGFloat(3), minTier: 5)
    private static let outerWall = (circumradius: 7.6 * cellRadius, width: CGFloat(2), minTier: 9)

    /// Outer extent from the hive centre of the drawn structure at a tier: the farthest cell vertex, or the
    /// outer edge of a wall stroke when one is present. Excludes the ambient glow, which may overhang.
    static func combRadius(visualTier: Int) -> CGFloat {
        let tier = min(max(visualTier, 1), maxTier)
        let r = cellRadius
        var extent = r   // centre cell (or the smaller-than-ring-1 queen chamber)
        for k in 1...3 {
            for (i, hex) in ring(k).enumerated() where includes(ring: k, index: i, tier: tier) {
                let c = pixel(hex)
                for j in 0..<6 {   // pointy-top vertices at 30° + 60°·j
                    let a = CGFloat.pi / 6 + CGFloat(j) * .pi / 3
                    extent = max(extent, hypot(c.x + r * cos(a), c.y + r * sin(a)))
                }
            }
        }
        for wall in [innerWall, outerWall] where tier >= wall.minTier {
            extent = max(extent, wall.circumradius + wall.width / 2)
        }
        return extent
    }

    // MARK: - Hex math

    /// Axial coordinates of ring `k`, east first, counter-clockwise.
    static func ring(_ k: Int) -> [(q: Int, s: Int)] {
        guard k > 0 else { return [(0, 0)] }
        var hex = (q: k, s: 0)
        var out: [(q: Int, s: Int)] = []
        for side in 0..<6 {
            let d = directions[(side + 2) % 6]
            for _ in 0..<k {
                out.append(hex)
                hex = (hex.q + d.q, hex.s + d.s)
            }
        }
        return out
    }

    static func pixel(_ hex: (q: Int, s: Int)) -> CGPoint {
        let r = cellRadius
        return CGPoint(x: r * sqrt(3) * (CGFloat(hex.q) + CGFloat(hex.s) / 2), y: r * 1.5 * CGFloat(hex.s))
    }

    /// Which ring cells are present at a tier (cumulative tier table).
    private static func includes(ring k: Int, index i: Int, tier: Int) -> Bool {
        switch k {
        case 1: return tier >= 2 || (i != 1 && i != 4)
        case 2: return tier >= 4 || (tier == 3 && i % 2 == 0)
        case 3: return tier >= 7 || (tier == 6 && i % 3 == 0)
        default: return false
        }
    }

    // MARK: - Layers

    private static func ambientGlow(tier: Int) -> SKNode {
        let strokeAlpha: CGFloat = tier >= 11 ? 0.4 : (tier >= 9 ? 0.3 : 0.22)
        let glow = SKShapeNode(circleOfRadius: 36 + 7 * CGFloat(tier))
        glow.fillColor = Palette.amber.withAlphaComponent(0.06)
        glow.strokeColor = Palette.amber.withAlphaComponent(strokeAlpha)
        glow.lineWidth = 1
        glow.glowWidth = 14 + 2 * CGFloat(tier)
        glow.alpha = tier == 1 ? 0.6 : 1   // tier 1: dim glow
        glow.zPosition = Z.glow
        glow.name = "glow"
        glow.run(.repeatForever(.sequence([
            .scale(to: 1.05, duration: 1.6),
            .scale(to: 1.0, duration: 1.6)
        ])))
        return glow
    }

    private static func cell(at p: CGPoint, color: UIColor, alpha: CGFloat) -> SKShapeNode {
        let n = SKShapeNode(path: Shapes.hexPath(circumradius: cellRadius, pointyTop: true))
        n.fillColor = color
        n.strokeColor = Palette.burntOrange
        n.lineWidth = 1
        n.glowWidth = 0
        n.isAntialiased = true
        n.alpha = alpha
        n.position = p
        n.zPosition = Z.cells
        return n
    }

    private static func wall(circumradius: CGFloat, color: UIColor, width: CGFloat) -> SKShapeNode {
        let n = SKShapeNode(path: Shapes.hexPath(circumradius: circumradius, pointyTop: false))
        n.fillColor = .clear
        n.strokeColor = color
        n.lineWidth = width
        n.glowWidth = 0
        n.lineJoin = .miter
        n.zPosition = Z.walls
        return n
    }

    /// Six spokes from the centre to the ring-3 corner cells (ring indices 0, 3, 6, 9, 12, 15).
    private static func honeyChannels() -> SKNode {
        let path = CGMutablePath()
        let corners = ring(3)
        for i in stride(from: 0, to: 18, by: 3) {
            path.move(to: .zero)
            path.addLine(to: pixel(corners[i]))
        }
        let n = SKShapeNode(path: path)
        n.strokeColor = Palette.gold
        n.lineWidth = 2
        n.lineCap = .round
        n.glowWidth = 0
        n.alpha = 0.5
        n.zPosition = Z.channels
        n.name = "channels"
        n.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.7, duration: 1.2),
            .fadeAlpha(to: 0.3, duration: 1.2)
        ])))
        return n
    }

    private static func queenChamber() -> SKNode {
        let r = cellRadius
        let chamber = SKShapeNode(path: Shapes.hexPath(circumradius: 1.6 * r, pointyTop: true))
        chamber.fillColor = Palette.gold
        chamber.strokeColor = Palette.burntOrange
        chamber.lineWidth = 1.5
        chamber.glowWidth = 0
        chamber.zPosition = Z.queen
        chamber.name = "queen"

        let inner = SKShapeNode(path: Shapes.hexPath(circumradius: 0.7 * r, pointyTop: true))
        inner.fillColor = Palette.white.withAlphaComponent(0.35)
        inner.strokeColor = .clear
        inner.glowWidth = 0
        chamber.addChild(inner)
        return chamber
    }

    /// Three gold triangles (side 8) seated on the queen chamber's roof, 10 pt apart, centre one highest.
    /// Each is filled without a base stroke and outlined only on its two upper sides, so it reads as a spire
    /// rising out of the roof rather than a separate sticker.
    private static func crown() -> SKNode {
        let apex = 1.6 * cellRadius
        let side: CGFloat = 8
        let height = side * sqrt(3) / 2
        let crown = SKNode()
        crown.zPosition = Z.crown
        crown.name = "crown"
        for x in [-10, 0, 10] as [CGFloat] {
            // Pointy-top roof: y = apex − |x|·tan 30°. Sink the base below the roof so no seam shows.
            let baseY = apex - abs(x) * tan(.pi / 6) - 2
            let left = CGPoint(x: x - side / 2, y: baseY)
            let right = CGPoint(x: x + side / 2, y: baseY)
            let top = CGPoint(x: x, y: baseY + height)

            let fillPath = CGMutablePath()
            fillPath.addLines(between: [left, right, top])
            fillPath.closeSubpath()
            let fill = SKShapeNode(path: fillPath)
            fill.fillColor = Palette.gold
            fill.strokeColor = .clear
            fill.glowWidth = 0
            crown.addChild(fill)

            let edgePath = CGMutablePath()
            edgePath.addLines(between: [left, top, right])
            let edge = SKShapeNode(path: edgePath)
            edge.strokeColor = Palette.burntOrange
            edge.lineWidth = 1
            edge.lineJoin = .miter
            edge.glowWidth = 0
            crown.addChild(edge)
        }
        return crown
    }
}
