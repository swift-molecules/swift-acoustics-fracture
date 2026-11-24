internal import Numeric

extension Acoustics.Fracture {
    /// A brittle, isotropic material: how stiff and heavy it is, what a new surface of it costs, how fast a crack
    /// can run through it, and how much a cycle of its vibration loses.
    public struct Material: Hashable, Sendable {
        public var young: Modulus.Young.Value<Double>
        public var density: Density.Value<Double>
        public var poisson: Poisson.Value<Double>
        /// The fracture surface energy γ, in joules per square metre: what one square metre of new surface costs.
        public var surface: Double
        /// The terminal speed of a running crack.
        public var crack: Velocity.Value<Double>
        public var loss: Loss.Value<Double>
        /// The bending stress at which a pane of it breaks: its modulus of rupture.
        public var rupture: Stress.Value<Double>

        @inlinable
        public init(
            young: Modulus.Young.Value<Double>,
            density: Density.Value<Double>,
            poisson: Poisson.Value<Double>,
            surface: Double,
            crack: Velocity.Value<Double>,
            loss: Loss.Value<Double>,
            rupture: Stress.Value<Double>
        ) {
            self.young = young
            self.density = density
            self.poisson = poisson
            self.surface = surface
            self.crack = crack
            self.loss = loss
            self.rupture = rupture
        }
    }
}

extension Acoustics.Fracture.Material {
    /// Soda-lime window glass.
    ///
    /// - Young's modulus 72 GPa, density 2500 kg/m³ and Poisson's ratio 0.22: the handbook values for soda-lime
    ///   silicate glass (Shelby, *Introduction to Glass Science and Technology*, 2nd ed., 2005).
    /// - Fracture surface energy 3.9 J/m² (Wiederhorn 1969, *J. Am. Ceram. Soc.* 52, 99–105).
    /// - Terminal crack speed 1500 m/s (Schardin 1959, in *Fracture*, Averbach et al., eds., 297–330).
    /// - Loss factor 0.001, inside the 0.0006 to 0.002 that Cremer, Heckl and Petersson (*Structure-Borne Sound*,
    ///   3rd ed., 2005) give for glass.
    /// - Modulus of rupture 41 MPa (6,000 psi), the mean breaking stress of annealed float glass (Glass Association
    ///   of North America, FM05-12, 2023; Pilkington, ATS-129).
    public static var glass: Self {
        Self(
            young: Modulus.Young.pascals(72e9),
            density: Density.amount(2500),
            poisson: Poisson.amount(0.22),
            surface: 3.9,
            crack: Velocity.amount(1500),
            loss: Loss.amount(0.001),
            rupture: Stress.amount(41e6)
        )
    }

    /// The plane-strain fracture toughness K_IC = √(2 γ E / (1 − ν²)), in pascals times the square root of a metre:
    /// Griffith's (1921) energy balance, G = 2γ, in Irwin's (1957) stress-intensity form.
    public var toughness: Double {
        let nu = poisson.underlying
        return (2 * surface * young.underlying / (1 - nu * nu)).squareRoot()
    }

    /// The stress at which a through crack of half-length `flaw` runs, Griffith's (1921) σ = √(2 E γ / (π a)) for
    /// plane stress.
    public func strength(flaw: Length<Space.Physical, Double>) -> Stress.Value<Double> {
        Stress.amount((2 * young.underlying * surface / (Double.pi * flaw.underlying)).squareRoot())
    }

    /// The speed of a longitudinal wave in a bar of the material, √(E / ρ).
    public var bar: Velocity.Value<Double> {
        Velocity.amount((young.underlying / density.underlying).squareRoot())
    }

    /// The mean fragment size when the material breaks at strain rate `rate` (per second): Grady's (1982,
    /// *J. Appl. Phys.* 53, 322–325) energy balance, s = (√20 K_IC / (ρ c ε̇))^(2/3), with c the bar speed.
    public func fragment(rate: Double) -> Length<Space.Physical, Double> {
        let ratio = 20.0.squareRoot() * toughness / (density.underlying * bar.underlying * rate)
        return Space.Physical.metres(Double.math.pow(ratio, 2.0 / 3.0))
    }
}
