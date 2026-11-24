import Acoustics_Fracture
import Numeric
import Testing

@Suite struct `Acoustics.Fracture.Impact Tests` {
    let glass = Contact.Elastic(young: Modulus.Young.pascals(72e9), poisson: Poisson.amount(0.22))
    let wood = Acoustics.Fracture.Floor.douglasFir.elastic

    func impact(
        _ modes: [Acoustics.Fracture.Mode],
        restitution: Double = 1,
        tilt: Double = 0
    ) -> Acoustics.Fracture.Impact {
        Acoustics.Fracture.Impact(
            fragment: Mass.kilograms(0.01),
            corner: Mass.kilograms(0.0025),
            speed: Velocity.amount(4),
            tilt: tilt,
            modes: modes,
            radius: Space.Physical.metres(0.002),
            between: glass,
            and: wood,
            restitution: restitution
        )
    }

    @Test func `a rigid corner presses for Hertz's 2.94 δ* / v and takes the impulse (1 + e) m v`() {
        let modulus = glass.contact(with: wood).underlying
        let deepest = Double.math.pow(15 * 0.0025 * 16 / (16 * modulus * 0.002.squareRoot()), 0.4)
        let elastic = impact([])
        #expect(abs(elastic.duration.underlying / (2.94 * deepest / 4) - 1) < 0.01)
        #expect(abs(elastic.impulse / (2 * 0.0025 * 4) - 1) < 0.005)
        let lossy = impact([], restitution: 0.3)
        #expect(abs(lossy.impulse / (1.3 * 0.0025 * 4) - 1) < 0.005)
    }

    @Test func `a slow mode is struck as by an impulse, φ J / m, and a mode with a node at the corner not at all`() {
        let slow = Acoustics.Fracture.Mode(
            frequency: Frequency.hertz(20),
            efficiency: 0,
            corner: 2,
            release: Velocity.amount(0)
        )
        let still = Acoustics.Fracture.Mode(
            frequency: Frequency.hertz(5000),
            efficiency: 0,
            corner: 0,
            release: Velocity.amount(0)
        )
        let result = impact([slow, still])
        let ring = result.rings[0]
        // A mode far below 1/T rings as if struck by the whole impulse J at once: speed φ J / m.
        let speed = (ring.re * ring.re + ring.im * ring.im).squareRoot()
        #expect(abs(speed / (2 * result.impulse / 0.01) - 1) < 0.02)
        #expect(abs(result.rings[1].re) < 1e-12 && abs(result.rings[1].im) < 1e-12)
        // A face turned on edge takes none of a push along the floor's normal.
        let edge = impact([slow], tilt: Double.pi / 2).rings[0]
        #expect(abs(edge.re) < 1e-9 && abs(edge.im) < 1e-9)
    }
}
