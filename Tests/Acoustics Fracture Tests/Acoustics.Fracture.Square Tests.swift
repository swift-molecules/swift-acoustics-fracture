import Numeric
import Testing

@testable import Acoustics_Fracture

@Suite struct `Acoustics.Fracture.Square Tests` {
    /// Leissa's own Poisson's ratio, 0.3, on soda-lime glass otherwise.
    let leissa: Acoustics.Fracture.Material = {
        var material = Acoustics.Fracture.Material.glass
        material.poisson = Poisson.amount(0.3)
        return material
    }()

    @Test func `a free square rings at Leissa's eigenvalues`() {
        let a = 0.1
        let h = 0.001
        let square = Acoustics.Fracture.Square(side: a, thickness: h, material: leissa, air: .room)
        let d = 72e9 * h * h * h / (12 * (1 - 0.09))
        let root = (d / (2500 * h)).squareRoot()
        // Leissa (1969), Vibration of Plates, NASA SP-160, Table 4.65, the completely free square with ν = 0.3:
        // ω a² √(ρh / D) = 13.4728, 19.5961, 24.2702.
        for (mode, lambda) in zip(square.modes, [13.4728, 19.5961, 24.2702]) {
            let expected = lambda / (2 * Double.pi * a * a) * root
            #expect(abs(mode.frequency / expected - 1) < 0.01, "found \(mode.frequency) Hz, Leissa \(expected) Hz")
        }
    }

    @Test func `the twist takes a twist, the saddle and the ring take bends, and the saddle's corners stand still`() {
        let square = Acoustics.Fracture.Square(side: 0.05, thickness: 0.004, material: .glass, air: .room)
        let (twist, saddle, ring) = (square.modes[0], square.modes[1], square.modes[2])
        #expect(abs(twist.bend.xx) < 1e-9 && abs(twist.bend.yy) < 1e-9 && twist.bend.xy > 0.05)
        #expect(abs(saddle.bend.xx + saddle.bend.yy) < 1e-9 && abs(saddle.corner) < 1e-6)
        #expect(abs(ring.bend.xx - ring.bend.yy) < 1e-9 && ring.corner > 1)
        // A bend along a diagonal is half a twist and half the ring's; along x, none of the twist.
        #expect(abs(twist.bending(along: 0)) < 1e-9)
        #expect(abs(twist.bending(along: Double.pi / 4) - twist.bend.xy) < 1e-9)
    }

    @Test func `a bend released into the modes gives them no more than its strain energy, ½ D κ² per area`() {
        // A cylindrical bend w = ½ κ x² of a plate stores ½ D κ² per area (Timoshenko and Woinowsky-Krieger 1959, §2).
        let a = 0.05
        let h = 0.004
        let square = Acoustics.Fracture.Square(side: a, thickness: h, material: .glass, air: .room)
        let kappa = 0.1
        let d = 72e9 * h * h * h / (12 * (1 - 0.22 * 0.22))
        let stored = 0.5 * d * kappa * kappa * a * a
        let mass = 2500 * h * a * a
        var taken = 0.0
        for mode in square.modes {
            let q = kappa * a * a * mode.bending(along: 0)
            let omega = 2 * Double.pi * mode.frequency
            taken += 0.5 * mass * omega * omega * q * q
        }
        #expect(taken <= stored)
        #expect(taken > 0.5 * stored, "the lowest modes take \(taken / stored) of the bend")
    }

    @Test func `efficiency rises toward one as the square grows past its coincidence`() {
        let small = Acoustics.Fracture.Square(side: 0.03, thickness: 0.004, material: .glass, air: .room)
        let large = Acoustics.Fracture.Square(side: 0.2, thickness: 0.004, material: .glass, air: .room)
        for (s, l) in zip(small.modes, large.modes) {
            #expect(s.efficiency > 0.5 && s.efficiency < 1.5)
            #expect(l.efficiency < 0.05)
        }
    }
}
