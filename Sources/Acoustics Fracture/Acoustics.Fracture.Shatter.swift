internal import Numeric

extension Acoustics.Fracture {
    /// A broken pane: its fragments, each rung by the crack that frees it and again by every landing.
    public struct Shatter: Hashable, Sendable {
        public var material: Material
        public var thickness: Length<Space.Physical, Double>
        public var floor: Floor
        public var air: Acoustics.Air
        public var fragments: [Fragment]

        @inlinable
        public init(
            material: Material,
            thickness: Length<Space.Physical, Double>,
            floor: Floor = .douglasFir,
            air: Acoustics.Air = .room,
            fragments: [Fragment]
        ) {
            self.material = material
            self.thickness = thickness
            self.floor = floor
            self.air = air
            self.fragments = fragments
        }
    }
}

extension Acoustics.Fracture.Shatter {
    /// The landing `bounce` of `fragment`, followed through its contact with `modes` of it.
    public func impact(
        _ bounce: Acoustics.Fracture.Bounce,
        of fragment: Acoustics.Fracture.Fragment,
        modes: [Acoustics.Fracture.Mode]
    ) -> Acoustics.Fracture.Impact {
        Acoustics.Fracture.Impact(
            fragment: fragment.mass,
            corner: bounce.mass,
            speed: bounce.speed,
            tilt: bounce.tilt,
            modes: modes,
            radius: Space.Physical.metres(thickness.underlying / 2),
            between: Contact.Elastic(young: material.young, poisson: material.poisson),
            and: floor.elastic,
            restitution: bounce.restitution
        )
    }

    /// The loss factor a mode of `fragment` has from radiating out of both faces, 2 ρ₀ c σ / (ω ρ h)
    /// (Cremer, Heckl and Petersson 2005, *Structure-Borne Sound*, §7.4).
    public func radiation(_ mode: Acoustics.Fracture.Mode) -> Double {
        let omega = 2 * Double.pi * mode.frequency.underlying
        let rho = material.density.underlying * thickness.underlying
        return 2 * air.density.underlying * air.speed.underlying * mode.efficiency / (omega * rho)
    }

    /// The pressure amplitude, per unit of the mode's speed, that a mode of `fragment` sends `distance` away.
    ///
    /// Both faces radiate W = ρ₀ c σ S V² (each ½ ρ₀ c σ S V², the mean square of its velocity being ½ V²), and
    /// spread evenly over a sphere this is a mean square pressure ρ₀ c W / 4π r², an amplitude
    /// ρ₀ c V √(σ S / 2π) / r.
    public func gain(_ mode: Acoustics.Fracture.Mode, of fragment: Acoustics.Fracture.Fragment, at distance: Double)
        -> Double
    {
        let rc = air.density.underlying * air.speed.underlying
        return rc * (mode.efficiency * fragment.area.underlying / (2 * Double.pi)).squareRoot() / distance
    }

    /// The dipole moment, per newton of the floor's push, that `bounce` gives `fragment` through the air it carries:
    /// the face's entrained mass m_a = 8 ρ₀ b³ / 3 of the disk of its area, b = √(S / π) (Lamb 1932,
    /// *Hydrodynamics*, §108), moving along its normal, and the air it displaces, ρ₀ V, moving with it.
    func dipole(_ bounce: Acoustics.Fracture.Bounce, of fragment: Acoustics.Fracture.Fragment) -> Double {
        let rho = air.density.underlying
        let radius = (fragment.area.underlying / Double.pi).squareRoot()
        let entrained = 8 * rho * radius * radius * radius / 3
        let displaced = rho * fragment.area.underlying * thickness.underlying
        let c = Double.math.cos(bounce.tilt)
        let normal = entrained * c + displaced * c
        let along = displaced * Double.math.sin(bounce.tilt)
        return (normal * normal + along * along).squareRoot() / fragment.mass.underlying
    }

    /// The sound pressure `distance` from the fragments, one value for each `interval` over `count` intervals, from
    /// the moment the pane broke, in free air: no floor reflection and no room.
    ///
    /// - **Rings.** A mode struck to complex speed U at t₀ moves at Re(U e^(iω(t−t₀))) e^(−σ(t−t₀)), with
    ///   σ = π f (η + η_rad), the material's loss and its radiation's; its pressure is `gain` times that. The crack
    ///   leaves it displaced and at rest, so its speed is −V sin ω(t − t₀) with V the mode's `release`. A landing
    ///   strikes the fragment's corner and its modes together through Hertz's contact, and leaves each mode
    ///   ringing as `impact` finds. A mode at or above half the
    ///   sampling rate is left out; each strike is followed until it has fallen 120 dB.
    /// - **Ticks.** The landing's push jolts the whole fragment, and a compact body whose acceleration changes
    ///   radiates as a dipole, p = (cos ϑ / 4π c r) d/dt [(m_a + ρ₀ V) a] (Koss and Alfredson 1973, *J. Sound Vib.*
    ///   27, 59–75, for a sphere), taken at its root mean square over directions, cos ϑ → 1/√3. Each sample is the
    ///   mean over its interval, the change of the moment across it over the interval's length, so the tick is
    ///   heard whatever the fragment's size, even where its modes are above hearing.
    public func pressures(
        count: Int,
        interval: Time.Duration.Value<Double>,
        distance: Length<Space.Physical, Double>
    ) -> [Pressure.Value<Double>] {
        let dt = interval.underlying
        let r = distance.underlying
        let eta = material.loss.underlying
        let c = air.speed.underlying
        var out = [Double](repeating: 0, count: count)
        for fragment in fragments {
            let heard = fragment.modes.filter { $0.frequency.underlying * dt < 0.5 && $0.frequency.underlying > 0 }
            let impacts = fragment.bounces.map { impact($0, of: fragment, modes: heard) }
            for (index, mode) in heard.enumerated() {
                let f = mode.frequency.underlying
                let omega = 2 * Double.pi * f
                let sigma = Double.pi * f * (eta + radiation(mode))
                let g = gain(mode, of: fragment, at: r)
                var strikes: [(time: Double, re: Double, im: Double)] = [
                    (fragment.released.underlying, 0, mode.release.underlying)
                ]
                for (bounce, impact) in zip(fragment.bounces, impacts) {
                    strikes.append((bounce.time.underlying, impact.rings[index].re, impact.rings[index].im))
                }
                for strike in strikes {
                    Self.ring(
                        into: &out,
                        from: strike.time,
                        amplitude: (g * strike.re, g * strike.im),
                        omega: omega,
                        sigma: sigma,
                        step: dt
                    )
                }
            }
            for (bounce, impact) in zip(fragment.bounces, impacts) {
                let scale = dipole(bounce, of: fragment) / (4 * Double.pi * c * r * 3.0.squareRoot()) / dt
                let t0 = bounce.time.underlying
                let end = t0 + impact.duration.underlying
                var j = Swift.max(Int((t0 / dt).rounded(.down)), 0)
                while j < count, Double(j) * dt <= end {
                    let before = impact.force(at: Double(j) * dt - t0)
                    let after = impact.force(at: Double(j + 1) * dt - t0)
                    out[j] += scale * (after - before)
                    j += 1
                }
            }
        }
        return out.map { Pressure.pascals($0) }
    }

    /// Adds Re((re + i im) e^(iω(t − t₀))) e^(−σ(t − t₀)) from t₀ on.
    static func ring(
        into out: inout [Double],
        from time: Double,
        amplitude: (re: Double, im: Double),
        omega: Double,
        sigma: Double,
        step dt: Double
    ) {
        let count = out.count
        let start = Swift.max(Int((time / dt).rounded(.up)), 0)
        guard start < count else { return }
        let offset = Double(start) * dt - time
        let length = Swift.min(count - start, Int((120 / 8.686 / sigma) / dt) + 1)
        let decay = Double.math.exp(-sigma * offset)
        let c0 = Double.math.cos(omega * offset)
        let s0 = Double.math.sin(omega * offset)
        var zr = decay * (amplitude.re * c0 - amplitude.im * s0)
        var zi = decay * (amplitude.re * s0 + amplitude.im * c0)
        let fade = Double.math.exp(-sigma * dt)
        let tr = fade * Double.math.cos(omega * dt)
        let ti = fade * Double.math.sin(omega * dt)
        for j in 0..<length {
            out[start + j] += zr
            (zr, zi) = (zr * tr - zi * ti, zr * ti + zi * tr)
        }
    }
}
