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
    /// The pane broken from the point (`x`, `y`) at strain rate `rate` (per second), its fragments landing on
    /// `floor` and radiating into `air`.
    ///
    /// - Fragment areas are drawn from Grady and Kipp's (1985, *J. Appl. Phys.* 58, 1210–1222) linear exponential
    ///   distribution, N(> A) ∝ exp(−A / Ā), with Ā = s² from `Material.fragment(rate:)`, until they fill the pane;
    ///   the last is cut to what is left, so the areas sum to the pane's.
    /// - Each fragment sits at a point drawn evenly over the pane, and is freed when the crack front, running out
    ///   from the break at the material's terminal crack speed, reaches it.
    /// - Its modes are a free square's of its area (`Square`). It is cut free still bent as the pane was when it
    ///   broke, and rings from that shape: each mode starts displaced by the shape's share in it, at rest.
    /// - The pane bends as a simply supported circular plate of its area loaded at the break (Timoshenko and
    ///   Woinowsky-Krieger 1959, *Theory of Plates and Shells*, §19): at a distance r, M_r = P (1 + ν) ln(R / r) / 4π
    ///   and M_t = P ((1 + ν) ln(R / r) + 1 − ν) / 4π, held at r = b, their equivalent radius 0.325 h of a load
    ///   spread over a point, and at the plate's edge beyond R. P is what puts M_t at b to the modulus of rupture,
    ///   σ = 6 M / h². The curvatures are κ_r = 12 (M_r − ν M_t) / (E h³) and κ_t = 12 (M_t − ν M_r) / (E h³), and
    ///   the fragment's shape is w = ½ (κ_r x_r² + κ_t x_t²) along and across the line from the break.
    /// - It then falls and bounces as `Bounce.tumble` follows it, from its height in the pane, its face turned from
    ///   the floor by a tilt drawn evenly from `seed`: nothing here says how it leaves the frame.
    public func shatter(
        x: Length<Space.Physical, Double>,
        y: Length<Space.Physical, Double>,
        rate: Double,
        floor: Acoustics.Fracture.Floor = .douglasFir,
        air: Acoustics.Air = .room,
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
        let h = thickness.underlying
        let table = Self.squares(
            sides: areas.map { $0.squareRoot() },
            thickness: h,
            material: material,
            air: air
        )
        let place = Threefry.Draws(key: Threefry.Key(seed: seed), item: 1, stream: 0x706C_6163)
        let turn = Threefry.Draws(key: Threefry.Key(seed: seed), item: 3, stream: 0x7469_6C74)
        let fragments = areas.enumerated().map { k, area in
            let fx = width.underlying * place.unit(at: 2 * UInt64(k), as: Double.self)
            let fy = height.underlying * place.unit(at: 2 * UInt64(k) + 1, as: Double.self)
            let dx = fx - x.underlying
            let dy = fy - y.underlying
            let released = (dx * dx + dy * dy).squareRoot() / material.crack.underlying
            let side = area.squareRoot()
            let mass = material.density.underlying * h * area
            let direction = Double.math.atan2(dy, dx)
            let bend = curvatures(at: Space.Physical.metres((dx * dx + dy * dy).squareRoot()))
            let modes = Self.interpolate(table, side: side).map { mode in
                let omega = 2 * Double.pi * mode.frequency
                let displaced =
                    side * side
                    * (bend.radial * mode.bending(along: direction)
                        + bend.hoop * mode.bending(along: direction + Double.pi / 2))
                return Acoustics.Fracture.Mode(
                    frequency: Frequency.hertz(mode.frequency),
                    efficiency: mode.efficiency,
                    corner: mode.corner,
                    release: Velocity.amount(omega * displaced)
                )
            }
            let tilt = Double.pi / 2 * turn.unit(at: UInt64(k), as: Double.self)
            let bounces = Acoustics.Fracture.Bounce.tumble(
                side: side,
                mass: mass,
                height: elevation.underlying + fy,
                tilt: tilt,
                radius: h / 2,
                body: Contact.Elastic(young: material.young, poisson: material.poisson),
                floor: floor,
                from: released
            )
            return Acoustics.Fracture.Fragment(
                x: Space.Physical.metres(fx),
                y: Space.Physical.metres(fy),
                area: Area<Space.Physical>.amount(area),
                mass: Mass.kilograms(mass),
                released: Time.Duration.amount(released),
                modes: modes,
                bounces: bounces
            )
        }
        return Acoustics.Fracture.Shatter(
            material: material,
            thickness: thickness,
            floor: floor,
            air: air,
            fragments: fragments
        )
    }
}

extension Acoustics.Fracture.Pane {
    /// The pane's curvatures `distance` from the break, along and across the line from it, as it breaks: those of
    /// a simply supported circular plate of the pane's area, loaded at its centre so that its hoop stress at the
    /// load's equivalent radius 0.325 h is the modulus of rupture (Timoshenko and Woinowsky-Krieger 1959, §19).
    public func curvatures(at distance: Length<Space.Physical, Double>) -> (radial: Double, hoop: Double) {
        let h = thickness.underlying
        let nu = material.poisson.underlying
        let e = material.young.underlying
        let reach = (width.underlying * height.underlying / Double.pi).squareRoot()
        let point = 0.325 * h
        let load = material.rupture.underlying * h * h / 6 / ((1 + nu) * Double.math.log(reach / point) + 1 - nu)
        let l = Swift.max(Double.math.log(reach / Swift.max(distance.underlying, point)), 0)
        let mr = load * (1 + nu) * l
        let mt = load * ((1 + nu) * l + 1 - nu)
        return (12 * (mr - nu * mt) / (e * h * h * h), 12 * (mt - nu * mr) / (e * h * h * h))
    }
}

extension Acoustics.Fracture.Pane {
    /// Free squares from the smallest side whose lowest mode is below 24 kHz up to the largest side, a factor of √2
    /// apart, so that no fragment's modes need more than a few finite-element solutions.
    static func squares(
        sides: [Double],
        thickness h: Double,
        material: Acoustics.Fracture.Material,
        air: Acoustics.Air
    ) -> [Acoustics.Fracture.Square] {
        guard let smallest = sides.min(), let largest = sides.max() else { return [] }
        let nu = material.poisson.underlying
        let flexural = (material.young.underlying * h * h / (12 * (1 - nu * nu) * material.density.underlying))
            .squareRoot()
        let audible = (13.47 * flexural / (2 * Double.pi * 24_000)).squareRoot()
        let low = Swift.min(Swift.max(smallest, audible), largest)
        var out: [Acoustics.Fracture.Square] = []
        var side = low
        while true {
            out.append(Acoustics.Fracture.Square(side: side, thickness: h, material: material, air: air))
            if side >= largest { break }
            side = Swift.min(side * 2.0.squareRoot(), largest)
        }
        return out
    }

    /// A fragment's modes from the squares on either side of it: f a² and the shapes' values linearly in log side,
    /// the efficiency in log too. Below the smallest square f a² is held, as for a thin plate, and so is the rest.
    static func interpolate(_ table: [Acoustics.Fracture.Square], side: Double) -> [Acoustics.Fracture.Square.Mode] {
        guard let first = table.first, let last = table.last else { return [] }
        if table.count == 1 || side <= first.side {
            return first.modes.map { scaled($0, from: first.side, to: side) }
        }
        if side >= last.side { return last.modes.map { scaled($0, from: last.side, to: side) } }
        var k = 0
        while table[k + 1].side < side { k += 1 }
        let a = table[k]
        let b = table[k + 1]
        let t = Double.math.log(side / a.side) / Double.math.log(b.side / a.side)
        func mix(_ p: Double, _ q: Double) -> Double { p + (q - p) * t }
        return zip(a.modes, b.modes).map { p, q in
            let fa = mix(p.frequency * a.side * a.side, q.frequency * b.side * b.side)
            let floor = 1e-12
            let efficiency = Double.math.exp(
                mix(Double.math.log(Swift.max(p.efficiency, floor)), Double.math.log(Swift.max(q.efficiency, floor)))
            )
            return Acoustics.Fracture.Square.Mode(
                frequency: fa / (side * side),
                efficiency: efficiency,
                corner: mix(p.corner, q.corner),
                bend: (mix(p.bend.xx, q.bend.xx), mix(p.bend.yy, q.bend.yy), mix(p.bend.xy, q.bend.xy))
            )
        }
    }

    static func scaled(_ mode: Acoustics.Fracture.Square.Mode, from: Double, to side: Double)
        -> Acoustics.Fracture.Square.Mode
    {
        Acoustics.Fracture.Square.Mode(
            frequency: mode.frequency * from * from / (side * side),
            efficiency: mode.efficiency,
            corner: mode.corner,
            bend: mode.bend
        )
    }
}
