import Acoustics_Fracture
import Testing

@Suite struct `Acoustics.Fracture.Bounce Tests` {
    let g = 9.80665
    let glass = Contact.Elastic(young: Modulus.Young.pascals(72e9), poisson: Strain.Ratio.amount(0.22))

    func tumble(tilt: Double, height: Double = 1) -> [Acoustics.Fracture.Bounce] {
        Acoustics.Fracture.Bounce.tumble(
            side: 0.04,
            mass: 0.016,
            height: height,
            tilt: tilt,
            radius: 0.002,
            body: glass,
            floor: .douglasFir
        )
    }

    @Test func `a fragment on edge lands after falling freely, feels its whole mass, and rises at e v`() {
        let bounces = tumble(tilt: Double.pi / 2)
        let drop = 1 - 0.02
        let first = bounces[0]
        #expect(abs(first.time.underlying - (2 * drop / g).squareRoot()) < 1e-6)
        #expect(abs(first.speed.underlying - (2 * g * drop).squareRoot()) < 1e-4)
        #expect(abs(first.mass.underlying / 0.016 - 1) < 1e-9)
        // Straight up at e v and back down: the next landing 2 e v / g later, at e v.
        let rise = first.restitution * first.speed.underlying
        #expect(abs(bounces[1].time.underlying - first.time.underlying - 2 * rise / g) < 1e-5)
        #expect(abs(bounces[1].speed.underlying - rise) < 1e-4)
    }

    @Test func `a fragment landing flat on a corner feels a quarter of its mass, m / (1 + m r² / I)`() {
        // A rod of length L about its centre: I = m L² / 12, so with r = L / 2 the floor feels m / 4
        // (Stronge 2000, Impact Mechanics, ch. 5).
        let first = tumble(tilt: 0)[0]
        #expect(abs(first.mass.underlying / 0.016 - 0.25) < 1e-6)
        #expect(first.tilt < 1e-6)
    }

    @Test func `the bounces die away`() {
        for tilt in [0.1, 0.5, 1.0, 1.4] {
            let bounces = tumble(tilt: tilt)
            #expect(bounces.count > 1)
            #expect(bounces.last!.speed.underlying < 0.5 * bounces.first!.speed.underlying)
            #expect(zip(bounces, bounces.dropFirst()).allSatisfy { $0.time.underlying < $1.time.underlying })
            #expect(bounces.last!.time.underlying < 2)
        }
    }
}
