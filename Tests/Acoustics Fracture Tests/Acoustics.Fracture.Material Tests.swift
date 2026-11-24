import Acoustics_Fracture
import Numeric
import Testing

@Suite struct `Acoustics.Fracture.Material Tests` {
    let glass = Acoustics.Fracture.Material.sodaLimeGlass

    @Test func `soda-lime glass's toughness is the measured 0.75 MPa√m to 5%`() {
        // √(2 × 3.9 × 72 × 10⁹ / (1 − 0.22²)) = 0.768 MPa√m.
        #expect(abs(glass.toughness / 0.75e6 - 1) < 0.05)
        #expect(abs(glass.toughness - (2 * 3.9 * 72e9 / (1 - 0.0484)).squareRoot()) < 1e-6)
    }

    @Test func `Griffith's strength times √(π a) is √(2 E γ)`() {
        for flaw in [1e-6, 1e-5, 1e-4] {
            let sigma = glass.strength(flaw: Space.Physical.metres(flaw)).underlying
            #expect(abs(sigma * (Double.pi * flaw).squareRoot() / (2 * 72e9 * 3.9).squareRoot() - 1) < 1e-12)
        }
        // A 10 µm flaw: √(2 × 72 × 10⁹ × 3.9 / (π × 10⁻⁵)) = 134 MPa.
        #expect(abs(glass.strength(flaw: Space.Physical.metres(1e-5)).underlying / 1.337e8 - 1) < 1e-3)
    }

    @Test func `Grady's fragment size is (√20 K / (ρ c ε̇))^(2/3)`() {
        let c = (72e9 / 2500.0).squareRoot()
        let expected = Double.math.pow(20.0.squareRoot() * glass.toughness / (2500 * c * 100), 2.0 / 3.0)
        #expect(abs(glass.fragment(rate: 100).underlying / expected - 1) < 1e-12)
        // Ten times the strain rate gives fragments 10^(−2/3) the size.
        let ratio = glass.fragment(rate: 1000).underlying / glass.fragment(rate: 100).underlying
        #expect(abs(ratio - Double.math.pow(10, -2.0 / 3.0)) < 1e-12)
    }

    @Test func `the toughness has the dimension of a stress times the root of a length`() {
        // K² = 2 γ E: (M T⁻²)(M L⁻¹ T⁻²) = M² L⁻¹ T⁻⁴, the square of (M L⁻¹ T⁻²)(L^½).
        let energyPerArea = Quantity.Dimension(mass: 1, time: -2)
        let young = Quantity.Dimension.of(Modulus.Young.self)
        let stress = Quantity.Dimension.of(Stress.self)
        #expect(energyPerArea * young == stress * stress * Quantity.Dimension(length: 1))
    }
}
