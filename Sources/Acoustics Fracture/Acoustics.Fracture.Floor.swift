internal import Acoustics_Plate
internal import Numeric

extension Acoustics.Fracture {
    /// What the fragments land on: how stiff it is, the stress at which it crushes, and how a corner slides on it.
    public struct Floor: Hashable, Sendable {
        public var elastic: Contact.Elastic
        /// The stress at which its surface gives way under a pressing corner.
        public var yield: Stress.Value<Double>
        /// Coulomb's coefficient of friction at a landing corner.
        public var friction: Double

        @inlinable
        public init(elastic: Contact.Elastic, yield: Stress.Value<Double>, friction: Double = 0) {
            self.elastic = elastic
            self.yield = yield
            self.friction = friction
        }
    }
}

extension Acoustics.Fracture.Floor {
    /// Flat-sawn Douglas-fir floorboards, pressed across the grain: the radial modulus of swift-acoustics-plate's
    /// Douglas-fir (USDA Forest Products Laboratory 2021, *Wood Handbook*, FPL-GTR-282, Tables 5–1 and 5–3a), its
    /// Poisson's ratio μ_LR (Table 5–2), and the 5.5 MPa at which it crushes in compression perpendicular to the
    /// grain (Table 5–3a, "Douglas-fir, Coast", 12% moisture content). No measured friction of glass on wood was to
    /// hand, so a corner lands without friction.
    public static var douglasFir: Self {
        let wood = Acoustics.Plate.Material.Wood.douglasFir
        return Self(
            elastic: Contact.Elastic(young: wood.young.radial, poisson: wood.poisson.longitudinalRadial),
            yield: Stress.amount(5.5e6)
        )
    }

    /// The coefficient of restitution of a sphere of radius `radius` and mass `mass`, landing at `speed`, on this
    /// floor as it crushes: Johnson's (1985, *Contact Mechanics*, §11.5, eq. 11.47) fully plastic impact,
    /// e = 3.8 (Y / E*)^½ (½ m v² / (Y R³))^(−1/8), no more than 1.
    public func restitution(
        mass: Mass.Value<Double>,
        speed: Velocity.Value<Double>,
        radius: Length<Space.Physical, Double>,
        against body: Contact.Elastic
    ) -> Double {
        let y = yield.underlying
        let modulus = body.contact(with: elastic).underlying
        let r = radius.underlying
        let energy = 0.5 * mass.underlying * speed.underlying * speed.underlying
        guard energy > 0 else { return 1 }
        let e = 3.8 * (y / modulus).squareRoot() * Double.math.pow(energy / (y * r * r * r), -0.125)
        return Swift.min(e, 1)
    }
}
