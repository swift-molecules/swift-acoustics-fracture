import Acoustics_Fracture
import Testing

@Suite struct `Acoustics.Fracture Tests` {
    @Test func `standard gravity is the 1901 CGPM's`() {
        #expect(Acoustics.Fracture.gravity.underlying == 9.80665)
    }
}
