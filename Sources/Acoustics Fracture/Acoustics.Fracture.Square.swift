internal import Acoustics_Plate
internal import Numeric

extension Acoustics.Fracture {
    /// A free square of glass as finite elements see it: for each of its three lowest bending modes, how fast it
    /// rings, how well it radiates, how far it moves at a corner and how much of a bend it takes up.
    ///
    /// The modes are swift-acoustics-plate's: Reissner–Mindlin quadrilaterals (MITC4) on a `cells` × `cells` grid,
    /// with a completely free edge, so the first three are rigid motions and are skipped. Each shape is scaled to a
    /// mean square of one over the square (mass-normalised: a mode at speed V carries ½ m V²).
    internal struct Square: Hashable, Sendable {
        /// The side.
        let side: Double
        let modes: [Mode]

        init(side: Double, thickness: Double, material: Acoustics.Fracture.Material, air: Acoustics.Air) {
            self.side = side
            let n = Self.cells
            let mesh = Mesh<Point<2, Double>>(columns: Cardinal(UInt(n)), rows: Cardinal(UInt(n))) { column, row in
                Point<2, Double>(
                    x: side * Double(Int(bitPattern: column)) / Double(n),
                    y: side * Double(Int(bitPattern: row)) / Double(n)
                )
            }
            let plate = Acoustics.Plate(
                mesh: mesh,
                thickness: Space.Physical.metres(thickness),
                material: .isotropic(density: material.density, young: material.young, poisson: material.poisson),
                edge: .free
            )
            let found: Acoustics.Plate.Modes
            do {
                found = try Acoustics.Plate.Modes(plate, count: 6, air: air)
            } catch {
                preconditionFailure("A free square of quads has six modes")
            }
            let mass = material.density.underlying * thickness * side * side
            func weight(_ i: Int) -> Double { (i == 0 || i == n) ? 0.5 : 1 }
            self.modes = found.dropFirst(3).map { mode in
                let scale = (mass / mode.mass.underlying).squareRoot()
                var xx = 0.0
                var yy = 0.0
                var xy = 0.0
                for row in 0...n {
                    for column in 0...n {
                        let w = weight(row) * weight(column) / Double(n * n)
                        let phi = mode.shape[row * (n + 1) + column] * scale
                        let x = Double(column) / Double(n) - 0.5
                        let y = Double(row) / Double(n) - 0.5
                        xx += w * phi * 0.5 * x * x
                        yy += w * phi * 0.5 * y * y
                        xy += w * phi * x * y
                    }
                }
                let corner = mode.shape[0] * scale
                let sign: Double = (Swift.abs(corner) > 1e-6 ? corner : xx + xy) < 0 ? -1 : 1
                return Mode(
                    frequency: mode.frequency.underlying,
                    efficiency: mode.efficiency,
                    corner: sign * corner,
                    bend: (sign * xx, sign * yy, sign * xy)
                )
            }
        }
    }
}

extension Acoustics.Fracture.Square {
    static var cells: Int { 16 }
}
