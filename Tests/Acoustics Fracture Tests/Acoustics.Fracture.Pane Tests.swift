import Acoustics_Fracture
import Testing

@Suite struct `Acoustics.Fracture.Pane Tests` {
    let pane = Acoustics.Fracture.Pane(
        width: Space.Physical.metres(0.6),
        height: Space.Physical.metres(0.4),
        thickness: Space.Physical.metres(0.004),
        elevation: Space.Physical.metres(0.9)
    )

    @Test func `the fragments fill the pane exactly, with a mean area near Grady's s²`() {
        let shatter = pane.shatter(x: Space.Physical.metres(0.3), y: Space.Physical.metres(0.2), rate: 30, seed: 4)
        let total = shatter.fragments.reduce(0.0) { $0 + $1.area.underlying }
        #expect(abs(total - 0.24) < 1e-12)
        let size = pane.material.fragment(rate: 30).underlying
        let mean = total / Double(shatter.fragments.count)
        #expect(shatter.fragments.count > 100)
        #expect(abs(mean / (size * size) - 1) < 0.15)
    }

    @Test func `the crack frees each fragment at the terminal crack speed, and it falls freely to the floor`() {
        let shatter = pane.shatter(x: Space.Physical.metres(0), y: Space.Physical.metres(0), rate: 30, seed: 4)
        let farthest = (0.6 * 0.6 + 0.4 * 0.4).squareRoot() / 1500
        for fragment in shatter.fragments {
            let dx = fragment.x.underlying
            let dy = fragment.y.underlying
            #expect(abs(fragment.released.underlying - (dx * dx + dy * dy).squareRoot() / 1500) < 1e-15)
            #expect(fragment.released.underlying <= farthest)
            let fall = (2 * (0.9 + dy) / 9.80665).squareRoot()
            #expect(abs(fragment.landed.underlying - fragment.released.underlying - fall) < 1e-12)
            #expect(abs(fragment.mass.underlying - 2500 * 0.004 * fragment.area.underlying) < 1e-15)
        }
    }

    @Test func `the same seed breaks the same way`() {
        let a = pane.shatter(x: Space.Physical.metres(0.1), y: Space.Physical.metres(0.3), rate: 30, seed: 2)
        let b = pane.shatter(x: Space.Physical.metres(0.1), y: Space.Physical.metres(0.3), rate: 30, seed: 2)
        #expect(a == b)
    }
}
