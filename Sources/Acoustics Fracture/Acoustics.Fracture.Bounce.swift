internal import Numeric

extension Acoustics.Fracture {
    /// One landing of a fragment's corner on the floor.
    public struct Bounce: Hashable, Sendable {
        /// When it lands, from the moment the pane broke.
        public var time: Time.Duration.Value<Double>
        /// How fast the corner comes down onto the floor.
        public var speed: Velocity.Value<Double>
        /// How far the fragment's face is turned from the floor as it lands, in radians: zero lying flat, π/2 on edge.
        public var tilt: Double
        /// The mass the floor feels at the corner, 1 / (1/m + r²/I) with r the corner's horizontal reach.
        public var mass: Mass.Value<Double>
        /// The coefficient of restitution of this landing.
        public var restitution: Double

        @inlinable
        public init(
            time: Time.Duration.Value<Double>,
            speed: Velocity.Value<Double>,
            tilt: Double,
            mass: Mass.Value<Double>,
            restitution: Double
        ) {
            self.time = time
            self.speed = speed
            self.tilt = tilt
            self.mass = mass
            self.restitution = restitution
        }
    }
}

extension Acoustics.Fracture.Bounce {
    /// A fragment's fall and bounces, seen edge on: a thin rod of length `side` and mass `mass`, its moment of inertia
    /// m a² / 12 about its centre, dropped from rest with its centre `height` above the floor, tilted by `tilt`.
    ///
    /// Between landings it falls freely and turns at a steady rate. A landing is a planar rigid-body impact at the
    /// lower end with Newton's restitution e and Coulomb friction μ (Brach 1989, *J. Appl. Mech.* 56, 133–138;
    /// Stronge 2000, *Impact Mechanics*, ch. 5): the impulse that stops the end sliding and sends it back up at e
    /// times its approach speed, unless that needs more than μ times its normal part, when the end slides and the
    /// tangential impulse is μ times the normal one. The fragment bounces until a landing comes down at less than
    /// 5 cm/s, or after 32 landings or 4 s.
    public static func tumble(
        side: Double,
        mass: Double,
        height: Double,
        tilt: Double,
        radius: Double,
        body: Contact.Elastic,
        floor: Acoustics.Fracture.Floor,
        from start: Double = 0
    ) -> [Self] {
        let g = Acoustics.Fracture.gravity.underlying
        let half = side / 2
        let inertia = mass * side * side / 12
        let mu = floor.friction
        var (y, theta, vx, vy, omega) = (height, tilt, 0.0, 0.0, 0.0)
        var now = 0.0
        var out: [Self] = []
        func low(_ t: Double) -> Double {
            y + vy * t - 0.5 * g * t * t - half * Swift.abs(Double.math.sin(theta + omega * t))
        }
        while out.count < 32 && now < 4 {
            let step = 1e-4
            var a = 0.0
            var b = step
            while low(b) > 0 && now + b < 4 {
                a = b
                b += step
            }
            guard low(b) <= 0 else { break }
            for _ in 0..<60 {
                let m = (a + b) / 2
                if low(m) > 0 { a = m } else { b = m }
            }
            let t = a
            now += t
            y += vy * t - 0.5 * g * t * t
            vy -= g * t
            theta += omega * t
            let s = Double.math.sin(theta)
            let sign: Double = s >= 0 ? -1 : 1
            let rx = sign * half * Double.math.cos(theta)
            let ry = sign * half * s
            let ct = vx - omega * ry
            let cn = vy + omega * rx
            let ktt = 1 / mass + ry * ry / inertia
            let knn = 1 / mass + rx * rx / inertia
            let ktn = -rx * ry / inertia
            guard cn < 0 else {
                now += 1e-6
                continue
            }
            let e = floor.restitution(
                mass: Mass.kilograms(1 / knn),
                speed: Velocity.amount(-cn),
                radius: Space.Physical.metres(radius),
                against: body
            )
            out.append(
                Self(
                    time: Time.Duration.amount(start + now),
                    speed: Velocity.amount(-cn),
                    tilt: Double.math.acos(Swift.min(Swift.abs(Double.math.cos(theta)), 1)),
                    mass: Mass.kilograms(1 / knn),
                    restitution: e
                )
            )
            let det = ktt * knn - ktn * ktn
            var pt = (knn * -ct - ktn * -(1 + e) * cn) / det
            var pn = (ktt * -(1 + e) * cn - ktn * -ct) / det
            if Swift.abs(pt) > mu * pn {
                let slide: Double = ct > 0 ? 1 : -1
                pn = -(1 + e) * cn / (knn - slide * mu * ktn)
                pt = -slide * mu * pn
            }
            vx += pt / mass
            vy += pn / mass
            omega += (rx * pn - ry * pt) / inertia
            if -cn < 0.05 { break }
        }
        return out
    }
}
