# swift-acoustics-fracture

Use this package when a sound comes from something brittle breaking, such as a window shattering: a crack runs out from the break at the material's terminal speed, frees fragments whose sizes follow from the material's toughness and how fast it was strained, and each fragment rings as a small free plate, once when it is freed and again when it lands on the floor. Start from `Acoustics.Fracture.Pane`, break it with `shatter(x:y:rate:seed:)`, and read the fragments' summed surface acceleration from the `Acoustics.Fracture.Shatter` with `accelerations(count:interval:seed:)`; turning that into sound pressure is radiation's work, not this package's.

## Laws

- `Material.glass`, soda-lime window glass, is E = 72 GPa, ρ = 2500 kg/m³, ν = 0.22 (Shelby 2005), γ = 3.9 J/m² (Wiederhorn 1969), a terminal crack speed of 1500 m/s (Schardin 1959) and a loss factor of 0.001 (inside Cremer, Heckl and Petersson's 0.0006 to 0.002 for glass).
- Its toughness is Griffith's (1921) energy balance in Irwin's form, K_IC = √(2 γ E / (1 − ν²)): 0.768 MPa√m, within 5% of the measured 0.75. Griffith's strength is σ = √(2 E γ / (π a)).
- The mean fragment size is Grady's (1982), s = (√20 K_IC / (ρ c ε̇))^(2/3) with c = √(E / ρ); fragment areas follow Grady and Kipp's (1985) linear exponential with mean s² until they fill the pane, and the last is cut so they sum to its area exactly.
- A fragment is freed when the crack front reaches its place, its distance from the break over the crack speed, and lands √(2 (elevation + y) / g) later, with g = 9.806 65 m/s² (3rd CGPM, 1901).
- A fragment rings in the three lowest modes of a free square plate of its area, λ² = 13.468, 19.596 and 24.270 (Leissa 1969, at ν = 0.3), f = λ² / (2π a²) √(D / (ρ h)). A mode decays at σ = π f η, so it falls 60 dB in 6.908 / σ.
- The crack gives a fragment's vibration the energy of its new faces, γ × perimeter × thickness, shared equally among its modes; the floor gives each mode the speed of the fall, g × fall time. Both are this model's own choices, with mass-normalised modes; neither is a measurement. A mode at or above half the sampling rate is left out.
- Surface energy and toughness are plain numbers (J/m² and Pa√m) until they have quantity atoms of their own.
