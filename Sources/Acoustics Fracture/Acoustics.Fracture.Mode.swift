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
