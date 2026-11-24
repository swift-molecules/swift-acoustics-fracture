internal import Numeric
internal import Threefry

extension Acoustics.Fracture {
    /// A broken pane: its fragments, each rung twice, once by the crack that frees it and once by the floor.
    public struct Shatter: Hashable, Sendable {
        public var material: Material
        public var thickness: Length<Space.Physical, Double>
        public var fragments: [Fragment]

        @inlinable
        public init(material: Material, thickness: Length<Space.Physical, Double>, fragments: [Fragment]) {
            self.material = material
            self.thickness = thickness
            self.fragments = fragments
        }
    }
}

extension Acoustics.Fracture.Shatter {
    /// The speed each mode of `fragment` is given by the crack that frees it.
    ///
    /// The fragment's vibration takes the energy of its new faces, γ × perimeter × thickness, with the perimeter of
    /// the square of its area, shared equally among its modes; each mode is mass-normalised, so a mode given energy E
    /// moves at √(2 E / m). Both the share and the normalisation are this model's own choices, not measurements.
    public func crack(_ fragment: Acoustics.Fracture.Fragment) -> Velocity.Value<Double> {
        let perimeter = 4 * fragment.area.underlying.squareRoot()
        let energy = material.surface * perimeter * thickness.underlying / Double(Swift.max(fragment.modes.count, 1))
        return Velocity.amount((2 * energy / fragment.mass.underlying).squareRoot())
    }

    /// The speed each mode of `fragment` is given by the floor: the impulse m v of its fall, v = g × its fall time,
    /// struck where its mass-normalised shape is one, gives every mode the speed v (this model's own choice).
    public func landing(_ fragment: Acoustics.Fracture.Fragment) -> Velocity.Value<Double> {
        let fall = fragment.landed.underlying - fragment.released.underlying
        return Velocity.amount(Acoustics.Fracture.gravity.underlying * fall)
    }

    /// The summed surface acceleration of every fragment's modes, one value for each `interval` over `count`
    /// intervals, from the moment the pane broke.
    ///
    /// A mode of frequency f struck to speed V moves as V e^(−σ t) sin(2π f t) and accelerates as its derivative,
    /// with σ = π f η, the amplitude decay rate of loss factor η, so its level falls 60 dB in 6.908 / σ. The two
    /// strikes add. A mode at or above half the sampling rate is left out, and each strike is followed until it
    /// has fallen 120 dB. The sign of each strike, where the mode shape is struck, is drawn from `seed`.
    public func accelerations(
        count: Int,
        interval: Time.Duration.Value<Double>,
        seed: UInt64 = 0
    ) -> [Acceleration.Value<Double>] {
        let dt = interval.underlying
        let eta = material.loss.underlying
        let signs = Threefry.Draws(key: Threefry.Key(seed: seed), item: 2, stream: 0x7369_676E)
        var out = [Double](repeating: 0, count: count)
        var draw: UInt64 = 0
        for fragment in fragments {
            let strikes = [(fragment.released, crack(fragment)), (fragment.landed, landing(fragment))]
            for mode in fragment.modes {
                let f = mode.underlying
                for (time, speed) in strikes {
                    let sign: Double = signs.unit(at: draw, as: Double.self) < 0.5 ? -1 : 1
                    draw += 1
                    guard f * dt < 0.5 else { continue }
                    let omega = 2 * Double.pi * f
                    let sigma = Double.pi * f * eta
                    let start = Int((time.underlying / dt).rounded(.up))
                    guard start < count else { continue }
                    let offset = Double(start) * dt - time.underlying
                    let length = Swift.min(count - start, Int((120 / 8.686 / sigma) / dt) + 1)
                    // d/dt [V e^(−σt) sin ωt] = V e^(−σt) (ω cos ωt − σ sin ωt).
                    let amplitude = sign * speed.underlying * Double.math.exp(-sigma * offset)
                    var re = Double.math.cos(omega * offset)
                    var im = Double.math.sin(omega * offset)
                    let c = Double.math.cos(omega * dt)
                    let s = Double.math.sin(omega * dt)
                    let fade = Double.math.exp(-sigma * dt)
                    var envelope = amplitude
                    for j in 0..<length {
                        out[start + j] += envelope * (omega * re - sigma * im)
                        (re, im) = (re * c - im * s, re * s + im * c)
                        envelope *= fade
                    }
                }
            }
        }
        return out.map { Acceleration.amount($0) }
    }
}
