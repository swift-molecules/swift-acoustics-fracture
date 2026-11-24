extension Acoustics.Fracture {
    /// A piece the crack has freed: where it was in the pane, its size, when the crack reached it, and the modes it
    /// rings in.
    public struct Fragment: Hashable, Sendable {
        /// Its place in the pane, from the pane's lower left corner.
        public var x: Length<Space.Physical, Double>
        public var y: Length<Space.Physical, Double>
        public var area: Area<Space.Physical>.Value<Double>
        public var mass: Mass.Value<Double>
        /// When the crack front reached it, from the moment the pane broke.
        public var released: Time.Duration.Value<Double>
        /// When it lands on the floor.
        public var landed: Time.Duration.Value<Double>
        /// Its three lowest modes, as a free square plate of the same area.
        public var modes: [Frequency.Value<Double>]

        @inlinable
        public init(
            x: Length<Space.Physical, Double>,
            y: Length<Space.Physical, Double>,
            area: Area<Space.Physical>.Value<Double>,
            mass: Mass.Value<Double>,
            released: Time.Duration.Value<Double>,
            landed: Time.Duration.Value<Double>,
            modes: [Frequency.Value<Double>]
        ) {
            self.x = x
            self.y = y
            self.area = area
            self.mass = mass
            self.released = released
            self.landed = landed
            self.modes = modes
        }
    }
}

extension Acoustics.Fracture.Fragment {
    /// λ² = ω a² √(ρ h / D) for the three lowest modes of a completely free square plate of side a, with ν = 0.3:
    /// 13.468, 19.596 and 24.270 (Leissa 1969, *Vibration of Plates*, NASA SP-160, §4.4).
    public static var eigenvalues: [Double] { [13.468, 19.596, 24.270] }

    /// The three lowest modes of a free square plate of side `side` and thickness `thickness`:
    /// f = λ² / (2π a²) √(D / (ρ h)), with D = E h³ / (12 (1 − ν²)).
    public static func modes(
        side: Length<Space.Physical, Double>,
        thickness: Length<Space.Physical, Double>,
        material: Acoustics.Fracture.Material
    ) -> [Frequency.Value<Double>] {
        let h = thickness.underlying
        let nu = material.poisson.underlying
        let rigidity = Rigidity.Plate.amount(material.young.underlying * h * h * h / (12 * (1 - nu * nu)))
        let a = side.underlying
        let root = (rigidity.underlying / (material.density.underlying * h)).squareRoot()
        return eigenvalues.map { Frequency.hertz($0 / (2 * Double.pi * a * a) * root) }
    }
}
