internal import Acoustics_Resonator
internal import Acoustics_Striker
internal import Numeric

extension Acoustics.Fracture {
    /// One landing followed through its contact: the floor, through Hertz's contact, strikes a resonator that holds
    /// the fragment's motion at its corner and its bending modes, and the force and what the modes are left with
    /// come out.
    ///
    /// - The corner is a sphere of half the thickness on the flat floor: `Contact.hertz`, F = (4/3) E* √R δ^(3/2)
    ///   (Johnson 1985, *Contact Mechanics*, eq. 4.23).
    /// - The fragment's motion at the corner is a resonance of no frequency with the corner's `Bounce.mass`; each
    ///   bending mode is one of its frequency and of the fragment's mass, moving the corner by φ cos(tilt) per metre,
    ///   φ its shape there. swift-acoustics-resonator steps them all, struck by the floor as a striker a million
    ///   times the fragment's mass, every 1/400 of Hertz's contact time 2.94 δ* / v,
    ///   δ* = (15 m v² / (16 E* √R))^(2/5) (Johnson 1985, §11.1), or finer where a mode needs it, until the step
    ///   after the floor last pressed.
    /// - Hertz's contact is elastic. The landing's restitution e leaves (1 + e) / 2 of its impulse, so the force and what each
    ///   mode is left with are scaled by that.
    public struct Impact: Hashable, Sendable {
        /// The step between force samples.
        public let step: Time.Duration.Value<Double>
        /// The force at each step from first touch, ending when the floor lets go.
        public let forces: [Force.Value<Double>]
        /// What each mode is left with: its speed V and phase as V e^(iϕ), Re(V e^(iϕ) e^(iωt)) after first touch.
        public let rings: [(re: Double, im: Double)]

        public static func == (l: Self, r: Self) -> Bool {
            l.step == r.step && l.forces == r.forces && l.rings.count == r.rings.count
                && zip(l.rings, r.rings).allSatisfy { $0.re == $1.re && $0.im == $1.im }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(step)
            hasher.combine(forces)
        }

        public init(
            fragment: Mass.Value<Double>,
            corner: Mass.Value<Double>,
            speed: Velocity.Value<Double>,
            tilt: Double,
            modes: [Acoustics.Fracture.Mode],
            radius: Length<Space.Physical, Double>,
            between first: Contact.Elastic,
            and second: Contact.Elastic,
            restitution: Double
        ) {
            let contact = Contact.hertz(radius: radius, between: first, and: second)
            let m = corner.underlying
            let v = speed.underlying
            let modulus = first.contact(with: second).underlying
            let deepest = Double.math.pow(15 * m * v * v / (16 * modulus * radius.underlying.squareRoot()), 0.4)
            let highest = modes.map { $0.frequency.underlying }.max() ?? 0
            let dt = Swift.min(2.94 * deepest / v / 400, highest > 0 ? 0.02 / highest : .infinity)
            let interval = Time.Duration.amount(dt)
            let c = Double.math.cos(tilt)
            var resonances = [
                Acoustics.Resonator.Mode(
                    frequency: Frequency.hertz(0),
                    decay: Decay.amount(0),
                    mass: corner,
                    reach: 1
                )
            ]
            for mode in modes {
                resonances.append(
                    Acoustics.Resonator.Mode(
                        frequency: mode.frequency,
                        decay: Decay.amount(0),
                        mass: fragment,
                        reach: mode.corner * c
                    )
                )
            }
            var resonator = Acoustics.Resonator(resonances, every: interval)
            resonator.strike(with: Acoustics.Striker(mass: Mass.kilograms(1e6 * m), contact: contact), at: speed)
            let scale = (1 + restitution) / 2
            var forces: [Force.Value<Double>] = [Force.newtons(0)]
            var before = resonator.displacements.map { $0.underlying }
            var now = before
            var steps = 0
            var pressed = false
            while steps < 100_000 {
                before = now
                resonator.advance()
                now = resonator.displacements.map { $0.underlying }
                forces.append(Force.newtons(scale * resonator.force.underlying))
                steps += 1
                if resonator.touching { pressed = true } else if pressed { break }
            }
            let t = Double(steps) * dt
            self.rings = modes.enumerated().map { index, mode in
                let omega = 2 * Double.pi * mode.frequency.underlying
                let q = now[index + 1]
                let velocity = (now[index + 1] - before[index + 1]) / dt
                let zr = scale * velocity
                let zi = scale * omega * q
                let cr = Double.math.cos(omega * t)
                let ci = -Double.math.sin(omega * t)
                return (zr * cr - zi * ci, zr * ci + zi * cr)
            }
            self.step = interval
            self.forces = forces
        }
    }
}

extension Acoustics.Fracture.Impact {
    /// How long the floor presses on the corner.
    public var duration: Time.Duration.Value<Double> {
        Time.Duration.amount(step.underlying * Double(forces.count - 1))
    }

    /// The impulse, ∫ F dt, by the trapezoid rule.
    public var impulse: Double {
        var sum = 0.0
        for index in 1..<forces.count { sum += 0.5 * (forces[index - 1].underlying + forces[index].underlying) }
        return sum * step.underlying
    }

    /// The force `time` after first touch, linear between samples and zero outside the contact.
    func force(at time: Double) -> Double {
        let x = time / step.underlying
        guard x > 0, x < Double(forces.count - 1) else { return 0 }
        let index = Int(x)
        let f = x - Double(index)
        return forces[index].underlying * (1 - f) + forces[index + 1].underlying * f
    }
}
