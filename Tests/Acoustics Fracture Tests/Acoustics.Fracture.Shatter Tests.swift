import Acoustics_Fracture
import Numeric
import Testing

@Suite struct `Acoustics.Fracture.Shatter Tests` {
    let rate = 48_000.0

    func single(_ hertz: Double, efficiency: Double = 1, release: Double = 1, bounces: [Acoustics.Fracture.Bounce] = [])
        -> Acoustics.Fracture.Shatter
    {
        let fragment = Acoustics.Fracture.Fragment(
            x: Space.Physical.metres(0),
            y: Space.Physical.metres(0),
            area: Area<Space.Physical>.amount(0.0025),
            mass: Mass.kilograms(0.025),
            released: Time.Duration.amount(0),
            modes: hertz > 0
                ? [
                    Acoustics.Fracture.Mode(
                        frequency: Frequency.hertz(hertz),
                        efficiency: efficiency,
                        corner: 2,
                        release: Velocity.amount(release)
                    )
                ] : [],
            bounces: bounces
        )
        return Acoustics.Fracture.Shatter(
            material: .glass,
            thickness: Space.Physical.metres(0.004),
            fragments: [fragment]
        )
    }

    func render(_ shatter: Acoustics.Fracture.Shatter, count: Int) -> [Double] {
        shatter.pressures(
            count: count,
            interval: Time.Duration.amount(1 / rate),
            distance: Space.Physical.metres(1)
        ).map { $0.underlying }
    }

    @Test func `radiation damps a mode by 2 ρ₀ c σ / (ω ρ h)`() {
        let shatter = single(5000)
        let mode = shatter.fragments[0].modes[0]
        let expected = 2 * 1.204 * 343.2 / (2 * Double.pi * 5000 * 2500 * 0.004)
        #expect(abs(shatter.radiation(mode) - expected) < 1e-15)
    }

    @Test func `a released mode sounds −ρ₀ c V √(σ S / 2π) / r sin ωt, falling at π f (η + η_rad)`() {
        let shatter = single(1000, efficiency: 0.5, release: 0.2)
        let mode = shatter.fragments[0].modes[0]
        let samples = render(shatter, count: 4800)
        let amplitude = 1.204 * 343.2 * 0.2 * (0.5 * 0.0025 / (2 * Double.pi)).squareRoot()
        #expect(abs(shatter.gain(mode, of: shatter.fragments[0], at: 1) * 0.2 - amplitude) < 1e-12)
        let sigma = Double.pi * 1000 * (0.001 + shatter.radiation(mode))
        for j in [1, 7, 100, 2345] {
            let t = Double(j) / rate
            let expected = -amplitude * Double.math.exp(-sigma * t) * Double.math.sin(2 * Double.pi * 1000 * t)
            #expect(abs(samples[j] - expected) < 1e-9 * amplitude)
        }
    }

    @Test func `a mode at or above half the sampling rate is left out`() {
        #expect(render(single(24_000), count: 100).allSatisfy { $0 == 0 })
    }

    @Test func `a landing's tick is the change of Koss and Alfredson's dipole, and sums to nothing`() {
        let bounce = Acoustics.Fracture.Bounce(
            time: Time.Duration.amount(0.01),
            speed: Velocity.amount(4),
            tilt: 0,
            mass: Mass.kilograms(0.025 / 4),
            restitution: 0.3
        )
        let shatter = single(0, bounces: [bounce])
        let samples = render(shatter, count: 2000)
        #expect(samples.contains { $0 != 0 })
        // p = d/dt [(m_a + ρ₀ V) a] / (4π c r √3): the moment is zero before and after, so the samples sum to zero.
        #expect(abs(samples.reduce(0, +)) < 1e-9 * samples.map { abs($0) }.max()!)
        // Lying flat, its face carries the air of the disk of its area, 8 ρ₀ b³ / 3 with b = √(S / π) (Lamb 1932).
        let b = (0.0025 / Double.pi).squareRoot()
        let carried = 8 * 1.204 * b * b * b / 3 + 1.204 * 0.0025 * 0.004
        let impact = shatter.impact(bounce, of: shatter.fragments[0], modes: [])
        let peak = impact.forces.map { $0.underlying }.max()!
        let rise = samples.prefix(Int(0.01 * rate) + 6).reduce(0, +) / rate
        let expected = carried * peak / 0.025 / (4 * Double.pi * 343.2 * 3.0.squareRoot())
        #expect(abs(rise / expected - 1) < 0.1, "the rise \(rise), the dipole \(expected)")
    }
}
