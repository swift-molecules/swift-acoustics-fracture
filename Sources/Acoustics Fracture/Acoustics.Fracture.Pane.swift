internal import Numeric
internal import Threefry

extension Acoustics.Fracture {
    /// A flat, upright pane of a brittle material, such as a window, standing with its lower edge `elevation` above
    /// the floor.
    public struct Pane: Hashable, Sendable {
        public var material: Material
        public var width: Length<Space.Physical, Double>
        public var height: Length<Space.Physical, Double>
        public var thickness: Length<Space.Physical, Double>
        public var elevation: Length<Space.Physical, Double>

        @inlinable
        public init(
            material: Material = .glass,
            width: Length<Space.Physical, Double>,
            height: Length<Space.Physical, Double>,
            thickness: Length<Space.Physical, Double>,
            elevation: Length<Space.Physical, Double>
        ) {
            self.material = material
            self.width = width
            self.height = height
            self.thickness = thickness
            self.elevation = elevation
        }
    }
}

extension Acoustics.Fracture.Pane {
    /// The pane broken from the point (`x`, `y`) at strain rate `rate` (per second).
    ///
    /// - Fragment areas are drawn from Grady and Kipp's (1985, *J. Appl. Phys.* 58, 1210–1222) linear exponential
    ///   distribution, N(> A) ∝ exp(−A / Ā), with Ā = s² from `Material.fragment(rate:)`, until they fill the pane;
    ///   the last is cut to what is left, so the areas sum to the pane's.
    /// - Each fragment sits at a point drawn evenly over the pane, and is freed when the crack front, running out
    ///   from the break at the material's terminal crack speed, reaches it.
    /// - It then falls freely from its height to the floor: √(2 (elevation + y) / g) later it lands.
    public func shatter(
        x: Length<Space.Physical, Double>,
        y: Length<Space.Physical, Double>,
        rate: Double,
        seed: UInt64 = 0
    ) -> Acoustics.Fracture.Shatter {
        let total = width.underlying * height.underlying
        let size = material.fragment(rate: rate).underlying
        let mean = size * size
        let draws = Threefry.Draws(key: Threefry.Key(seed: seed), item: 0, stream: 0x7368_6172)
        var areas: [Double] = []
        var filled = 0.0
        var index: UInt64 = 0
        while filled < total {
            let u = draws.unit(at: index, as: Double.self)
            index += 1
            let area = Swift.min(-mean * Double.math.log(1 - u), total - filled)
            guard area > 0 else { continue }
            areas.append(area)
            filled += area
        }
        let place = Threefry.Draws(key: Threefry.Key(seed: seed), item: 1, stream: 0x706C_6163)
        let fragments = areas.enumerated().map { k, area in
            let fx = width.underlying * place.unit(at: 2 * UInt64(k), as: Double.self)
            let fy = height.underlying * place.unit(at: 2 * UInt64(k) + 1, as: Double.self)
            let dx = fx - x.underlying
            let dy = fy - y.underlying
            let released = (dx * dx + dy * dy).squareRoot() / material.crack.underlying
            let fall = (2 * (elevation.underlying + fy) / Acoustics.Fracture.gravity.underlying).squareRoot()
            return Acoustics.Fracture.Fragment(
                x: Space.Physical.metres(fx),
                y: Space.Physical.metres(fy),
                area: Area<Space.Physical>.amount(area),
                mass: Mass.kilograms(material.density.underlying * thickness.underlying * area),
                released: Time.Duration.amount(released),
                landed: Time.Duration.amount(released + fall),
                modes: Acoustics.Fracture.Fragment.modes(
                    side: Space.Physical.metres(area.squareRoot()),
                    thickness: thickness,
                    material: material
                )
            )
        }
        return Acoustics.Fracture.Shatter(material: material, thickness: thickness, fragments: fragments)
    }
}
