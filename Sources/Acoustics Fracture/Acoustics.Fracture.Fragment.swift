extension Acoustics.Fracture {
    /// A piece the crack has freed: where it was in the pane, its size, when the crack reached it, the modes it rings
    /// in, and where it lands.
    public struct Fragment: Hashable, Sendable {
        /// Its place in the pane, from the pane's lower left corner.
        public var x: Length<Space.Physical, Double>
        public var y: Length<Space.Physical, Double>
        public var area: Area<Space.Physical>.Value<Double>
        public var mass: Mass.Value<Double>
        /// When the crack front reached it, from the moment the pane broke.
        public var released: Time.Duration.Value<Double>
        /// Its three lowest bending modes, as a free square of the same area.
        public var modes: [Mode]
        /// Its landings on the floor, in order.
        public var bounces: [Bounce]

        @inlinable
        public init(
            x: Length<Space.Physical, Double>,
            y: Length<Space.Physical, Double>,
            area: Area<Space.Physical>.Value<Double>,
            mass: Mass.Value<Double>,
            released: Time.Duration.Value<Double>,
            modes: [Mode],
            bounces: [Bounce]
        ) {
            self.x = x
            self.y = y
            self.area = area
            self.mass = mass
            self.released = released
            self.modes = modes
            self.bounces = bounces
        }
    }
}

extension Acoustics.Fracture.Fragment {
    /// When it first lands, or nil if it never does.
    public var landed: Time.Duration.Value<Double>? { bounces.first?.time }

    /// The side of the square of its area.
    public var side: Length<Space.Physical, Double> { Space.Physical.metres(area.underlying.squareRoot()) }
}

extension Acoustics.Fracture {
    /// One bending mode of a fragment, its shape scaled to a mean square of one over the fragment, so a mode moving
    /// at speed V carries ½ m V².
    public struct Mode: Hashable, Sendable {
        public var frequency: Frequency.Value<Double>
        /// The radiation efficiency of one face, as if set in a rigid baffle.
        public var efficiency: Double
        /// The shape at the corner that lands.
        public var corner: Double
        /// The speed the mode is left with when the crack frees the fragment, signed by the mode's phase.
        public var release: Velocity.Value<Double>

        @inlinable
        public init(
            frequency: Frequency.Value<Double>,
            efficiency: Double,
            corner: Double,
            release: Velocity.Value<Double>
        ) {
            self.frequency = frequency
            self.efficiency = efficiency
            self.corner = corner
            self.release = release
        }
    }
}
