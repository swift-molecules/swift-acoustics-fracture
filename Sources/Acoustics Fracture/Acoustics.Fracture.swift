extension Acoustics {
    /// The sound of something brittle breaking: a crack running through a pane at its terminal speed, the fragments
    /// it frees ringing as small free plates, and each fragment ringing again where it lands.
    public enum Fracture {}
}

extension Acoustics.Fracture {
    /// Standard acceleration of free fall, 9.806 65 m/s², as the 3rd CGPM (1901) defined it.
    public static var gravity: Acceleration.Value<Double> { Acceleration.amount(9.80665) }
}
