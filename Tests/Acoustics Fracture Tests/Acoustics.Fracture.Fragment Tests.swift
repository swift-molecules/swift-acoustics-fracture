import Acoustics_Fracture
import Testing

@Suite struct `Acoustics.Fracture.Fragment Tests` {
    let glass = Acoustics.Fracture.Material.sodaLimeGlass

    @Test func `a free square plate rings at Leissa's eigenvalues`() {
        let modes = Acoustics.Fracture.Fragment.modes(
            side: Space.Physical.metres(0.05), thickness: Space.Physical.metres(0.004), material: glass
        )
        let d = 72e9 * 0.004 * 0.004 * 0.004 / (12 * (1 - 0.22 * 0.22))
        let root = (d / (2500 * 0.004)).squareRoot()
        for (mode, lambda) in zip(modes, [13.468, 19.596, 24.270]) {
            #expect(abs(mode.underlying - lambda / (2 * Double.pi * 0.0025) * root) < 1e-9)
        }
        // A 5 cm square of 4 mm glass: its lowest mode near 5.4 kHz.
        #expect(abs(modes[0].underlying - 5_440) < 10)
    }

    @Test func `half the side rings four times as high, twice the thickness twice as high`() {
        let one = Acoustics.Fracture.Fragment.modes(
            side: Space.Physical.metres(0.04), thickness: Space.Physical.metres(0.003), material: glass
        )
        let half = Acoustics.Fracture.Fragment.modes(
            side: Space.Physical.metres(0.02), thickness: Space.Physical.metres(0.003), material: glass
        )
        let thick = Acoustics.Fracture.Fragment.modes(
            side: Space.Physical.metres(0.04), thickness: Space.Physical.metres(0.006), material: glass
        )
        #expect(abs(half[0] / one[0] - 4) < 1e-12)
        #expect(abs(thick[0] / one[0] - 2) < 1e-12)
    }
}
