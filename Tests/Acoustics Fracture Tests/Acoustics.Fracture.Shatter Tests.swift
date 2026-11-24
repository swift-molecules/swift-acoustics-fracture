import Acoustics_Fracture
import Numeric
import Testing

@Suite struct `Acoustics.Fracture.Shatter Tests` {
    let rate = 48_000.0

    func single(_ hertz: Double) -> Acoustics.Fracture.Shatter {
        let fragment = Acoustics.Fracture.Fragment(
            x: Space.Physical.metres(0),
            y: Space.Physical.metres(0),
            area: Area<Space.Physical>.amount(0.0025),
            mass: Mass.kilograms(0.025),
            released: Time.Duration.amount(0),
            landed: Time.Duration.amount(10),
            modes: [Frequency.hertz(hertz)]
        )
        return Acoustics.Fracture.Shatter(
            material: .glass,
            thickness: Space.Physical.metres(0.004),
            fragments: [fragment]
        )
    }

    @Test func `a mode falls 60 dB in 6.908 over π f η`() {
        let shatter = single(2_000)
        let samples = shatter.accelerations(count: 96_000, interval: Time.Duration.amount(1 / rate)).map(\.underlying)
        let t60 = 6.908 / (Double.pi * 2_000 * 0.001)
        func rms(at seconds: Double) -> Double {
            let start = Int(seconds * rate)
            let window = samples[start..<(start + 480)]
            return (window.reduce(0) { $0 + $1 * $1 } / 480).squareRoot()
        }
        let drop = 20 * Double.math.log(rms(at: 0.1) / rms(at: 0.1 + t60)) / Double.math.log(10)
        #expect(abs(drop - 60) < 0.1)
    }

    @Test func `the crack gives each mode the speed of its faces' surface energy`() {
        let shatter = single(2_000)
        let fragment = shatter.fragments[0]
        // γ × 4 √A × h over one mode: 3.9 × 0.2 × 0.004 J, so V = √(2 E / m).
        let energy = 3.9 * 4 * 0.05 * 0.004
        #expect(abs(shatter.crack(fragment).underlying - (2 * energy / 0.025).squareRoot()) < 1e-12)
        let first = shatter.accelerations(count: 1, interval: Time.Duration.amount(1 / rate))[0].underlying
        // At the strike the acceleration is ±ω V.
        #expect(abs(abs(first) - 2 * Double.pi * 2_000 * (2 * energy / 0.025).squareRoot()) < 1e-9)
    }

    @Test func `the floor gives each mode the speed of the fall`() {
        let shatter = single(2_000)
        #expect(abs(shatter.landing(shatter.fragments[0]).underlying - 9.80665 * 10) < 1e-12)
    }

    @Test func `a mode above half the sampling rate is silent`() {
        let samples = single(30_000).accelerations(count: 480, interval: Time.Duration.amount(1 / rate))
        #expect(samples.allSatisfy { $0 == .zero })
    }

    @Test func `a broken window is the same for the same seed`() {
        let pane = Acoustics.Fracture.Pane(
            width: Space.Physical.metres(0.3),
            height: Space.Physical.metres(0.2),
            thickness: Space.Physical.metres(0.004),
            elevation: Space.Physical.metres(0.5)
        )
        let shatter = pane.shatter(x: Space.Physical.metres(0.1), y: Space.Physical.metres(0.1), rate: 30, seed: 1)
        let interval = Time.Duration.amount(1 / rate)
        let a = shatter.accelerations(count: 4_800, interval: interval, seed: 3)
        #expect(a == shatter.accelerations(count: 4_800, interval: interval, seed: 3))
        #expect(a.contains { $0 != .zero })
    }
}
