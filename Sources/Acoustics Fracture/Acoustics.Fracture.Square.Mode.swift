internal import Numeric

extension Acoustics.Fracture.Square {
    struct Mode {
        let frequency: Double
        /// The radiation efficiency of one face as if in a rigid baffle, at the mode's own frequency.
        let efficiency: Double
        /// The shape at a corner.
        let corner: Double
        /// The mean of the shape times ½ (x/a)², ½ (y/a)² and (x/a)(y/a) over the square, x and y from its
        /// centre: the share of a bend w = ½ κ (x cos θ + y sin θ)² it takes, per κ a².
        let bend: (xx: Double, yy: Double, xy: Double)
    }
}

extension Acoustics.Fracture.Square.Mode: Hashable {
    static func == (l: Self, r: Self) -> Bool {
        l.frequency == r.frequency && l.efficiency == r.efficiency && l.corner == r.corner
            && l.bend.xx == r.bend.xx && l.bend.yy == r.bend.yy && l.bend.xy == r.bend.xy
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(frequency)
        hasher.combine(efficiency)
        hasher.combine(corner)
    }
}

extension Acoustics.Fracture.Square.Mode: Sendable {}

extension Acoustics.Fracture.Square.Mode {
    /// The bend's share for a bend along the direction at `angle` from the square's x axis.
    func bending(along angle: Double) -> Double {
        let c = Double.math.cos(angle)
        let s = Double.math.sin(angle)
        return c * c * bend.xx + s * s * bend.yy + 2 * c * s * bend.xy
    }
}
