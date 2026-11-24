import Acoustics_Fracture
import Numeric
import Testing

@Suite struct `Acoustics.Fracture.Floor Tests` {
    let floor = Acoustics.Fracture.Floor.douglasFir
    let glass = Contact.Elastic(young: Modulus.Young.pascals(72e9), poisson: Poisson.amount(0.22))

    func restitution(_ mass: Double, _ speed: Double, _ radius: Double) -> Double {
        floor.restitution(
            mass: Mass.kilograms(mass),
            speed: Velocity.amount(speed),
            radius: Space.Physical.metres(radius),
            against: glass
        )
    }

    @Test func `Douglas-fir across the grain is the Wood Handbook's`() {
        // Table 5–3a: 13,400 MPa, raised 10%; Table 5–1: E_R / E_L = 0.068; Table 5–2: μ_LR = 0.292.
        #expect(abs(floor.elastic.young.underlying - 13_400e6 * 1.1 * 0.068) < 1)
        #expect(floor.elastic.poisson.underlying == 0.292)
        #expect(floor.yield.underlying == 5.5e6)
    }

    @Test func `a crushing landing restitutes Johnson's 3.8 (Y / E*)^½ (½ m v² / (Y R³))^(−1/8)`() {
        let modulus = glass.contact(with: floor.elastic).underlying
        let (m, v, r) = (0.0025, 4.0, 0.002)
        let expected =
            3.8 * (5.5e6 / modulus).squareRoot() * Double.math.pow(0.5 * m * v * v / (5.5e6 * r * r * r), -0.125)
        #expect(abs(restitution(m, v, r) - expected) < 1e-12)
        #expect(expected > 0.2 && expected < 0.4)
        // e falls as v^(−1/4): sixteen times the speed is half the restitution.
        #expect(abs(restitution(m, 0.25, r) / restitution(m, 4, r) - 2) < 1e-12)
        // No landing gives back more than it took.
        #expect(restitution(m, 1e-6, r) == 1)
    }
}
