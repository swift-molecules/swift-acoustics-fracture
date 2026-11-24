import Acoustics_Fracture
import Numeric
import Testing

@Suite struct `Acoustics.Fracture.Break Tests` {
    @Test func `a pane breaks once and rains down, loudest at the break or first landings, then dies away`() {
        let pane = Acoustics.Fracture.Pane(
            width: Space.Physical.metres(0.3),
            height: Space.Physical.metres(0.2),
            thickness: Space.Physical.metres(0.004),
            elevation: Space.Physical.metres(0.9)
        )
        let shatter = pane.shatter(x: Space.Physical.metres(0.15), y: Space.Physical.metres(0.1), rate: 30, seed: 1)
        let rate = 24_000
        let samples = shatter.pressures(
            count: 2 * rate,
            interval: Time.Duration.amount(1 / Double(rate)),
            distance: Space.Physical.metres(2)
        ).map { $0.underlying }
        let window = rate / 20
        let levels = stride(from: 0, to: samples.count, by: window).map { start in
            samples[start..<(start + window)].reduce(0) { $0 + $1 * $1 }
        }
        let loudest = levels.indices.max { levels[$0] < levels[$1] }!
        #expect(loudest * window < rate * 3 / 5)
        // Within a second and a half, the rain is 40 dB below its loudest.
        #expect(levels[30] < levels[loudest] * 1e-4)
        #expect(samples.allSatisfy { $0.isFinite })
    }
}
