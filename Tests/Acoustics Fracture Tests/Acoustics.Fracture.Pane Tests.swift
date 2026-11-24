import Acoustics_Fracture
import Numeric
import Testing

@Suite struct `Acoustics.Fracture.Pane Tests` {
    let pane = Acoustics.Fracture.Pane(
        width: Space.Physical.metres(0.3),
        height: Space.Physical.metres(0.2),
        thickness: Space.Physical.metres(0.004),
        elevation: Space.Physical.metres(0.9)
    )

    @Test func `the fragments fill the pane exactly, with a mean area near Grady's s²`() {
        let shatter = pane.shatter(x: Space.Physical.metres(0.15), y: Space.Physical.metres(0.1), rate: 30, seed: 4)
        let total = shatter.fragments.reduce(0.0) { $0 + $1.area.underlying }
        #expect(abs(total - 0.06) < 1e-12)
        let size = pane.material.fragment(rate: 30).underlying
        let mean = total / Double(shatter.fragments.count)
        #expect(shatter.fragments.count > 20)
        #expect(abs(mean / (size * size) - 1) < 0.3)
    }

    @Test func `the crack frees each fragment at the terminal crack speed, and it first lands after falling freely`() {
        let shatter = pane.shatter(x: Space.Physical.metres(0), y: Space.Physical.metres(0), rate: 30, seed: 4)
        for fragment in shatter.fragments {
            let dx = fragment.x.underlying
            let dy = fragment.y.underlying
            #expect(abs(fragment.released.underlying - (dx * dx + dy * dy).squareRoot() / 1500) < 1e-15)
            #expect(abs(fragment.mass.underlying - 2500 * 0.004 * fragment.area.underlying) < 1e-15)
            // Its lower end, half a side times the sine of its tilt below its centre, falls 0.9 m + y less that.
            let first = fragment.bounces[0]
            let drop = 0.9 + dy - fragment.side.underlying / 2 * Double.math.sin(first.tilt)
            let fall = (2 * drop / 9.80665).squareRoot()
            #expect(abs(first.time.underlying - fragment.released.underlying - fall) < 1e-5)
        }
    }

    @Test func `the pane bends as Timoshenko's centrally loaded circular plate, at its modulus of rupture at the load`()
    {
        let h = 0.004
        let nu = 0.22
        let e = 72e9
        // At the load's equivalent radius 0.325 h the hoop stress 6 M_t / h² is the modulus of rupture.
        let at = pane.curvatures(at: Space.Physical.metres(0.325 * h))
        let d = e * h * h * h / (12 * (1 - nu * nu))
        let mt = d * (at.hoop + nu * at.radial)
        #expect(abs(6 * mt / (h * h) / 41e6 - 1) < 1e-12)
        // M_t − M_r = P (1 − ν) / 4π everywhere inside; M_r is zero at the edge of the circle of the pane's area.
        let edge = pane.curvatures(at: Space.Physical.metres((0.06 / Double.pi).squareRoot()))
        #expect(abs(d * (edge.radial + nu * edge.hoop)) < 1e-9)
        let near = pane.curvatures(at: Space.Physical.metres(0.01))
        let far = pane.curvatures(at: Space.Physical.metres(0.1))
        let difference = { (c: (radial: Double, hoop: Double)) in d * (1 - nu) * (c.hoop - c.radial) }
        #expect(abs(difference(near) / difference(far) - 1) < 1e-9)
        #expect(near.radial > far.radial)
    }

    @Test func `a fragment rings from the bend it was cut with, each mode at ω times its share`() {
        let shatter = pane.shatter(x: Space.Physical.metres(0.15), y: Space.Physical.metres(0.1), rate: 30, seed: 4)
        let near = shatter.fragments.min { $0.released.underlying < $1.released.underlying }!
        let far = shatter.fragments.max { $0.released.underlying < $1.released.underlying }!
        let speed = { (f: Acoustics.Fracture.Fragment) in
            f.modes.map { abs($0.release.underlying) }.reduce(0, +) / f.side.underlying
        }
        #expect(speed(near) > speed(far))
    }

    @Test func `the same seed breaks the same way`() {
        let a = pane.shatter(x: Space.Physical.metres(0.1), y: Space.Physical.metres(0.1), rate: 30, seed: 2)
        let b = pane.shatter(x: Space.Physical.metres(0.1), y: Space.Physical.metres(0.1), rate: 30, seed: 2)
        #expect(a == b)
    }
}
