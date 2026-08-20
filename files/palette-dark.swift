// >>> conductor palette >>>
// Dark palette. install.sh splices this block into files/conductor.swift, in
// place of that file's light block, to build the `conductor-dark` sidebar. Only
// this block differs between the two variants, so the view never diverges.
//
// Row slabs, pills and both neutral inks are painted here; the bar's ground
// belongs to cmux's `app.appearance`, which the switcher sets to dark in step
// with this file. Pill fills are deep tones with light labels, and the state
// hues are the brighter 500-weight versions, which hold up as a low-opacity
// wash over a dark slab.
//
// theme() carries the variant's identity: the appearance the switcher moves to,
// and how that button reads.
func theme(_ key: String) -> String {
    if key == "next" { return "light" }
    if key == "icon" { return "sun.max.fill" }
    return "Light"
}

func statusFill(_ label: String) -> String {
    return label == "RUNNING" ? "#1E3A8A" : (label == "WAITING" ? "#7C2D12" : "#14532D")
}

func statusText(_ label: String) -> String {
    return label == "RUNNING" ? "#BFDBFE" : (label == "WAITING" ? "#FED7AA" : "#BBF7D0")
}

func prFill(_ status: String, _ stale: Bool) -> String {
    if stale { return "#7C2D12" }
    return status == "merged" ? "#4C1D95" : (status == "closed" ? "#7F1D1D" : "#14532D")
}

func prText(_ status: String, _ stale: Bool) -> String {
    if stale { return "#FED7AA" }
    return status == "merged" ? "#DDD6FE" : (status == "closed" ? "#FECACA" : "#BBF7D0")
}

// Row wash. Blue while the tab works, orange while it is blocked on you, green
// once it is done. All three read louder than plain focus, so focus never hides
// a tab that wants something from you.
func rowWash(_ done: Bool, _ waiting: Bool) -> String {
    if waiting { return "#F97316" }
    return done ? "#22C55E" : "#3B82F6"
}

// Higher than the light variant: the same hue at the same opacity carries less
// separation over a dark ground.
func rowTint(_ active: Bool, _ focused: Bool) -> Double {
    if active && focused { return 0.30 }
    if active { return 0.22 }
    return focused ? 0.12 : 0.0
}

// Per-state accent: the row's left bar and its dot.
func accent(_ state: String) -> String {
    if state == "run" { return "#3B82F6" }
    if state == "wait" { return "#F97316" }
    return "#22C55E"
}

// Row glyph (spinner / terminal icon). Lighter than accent() so a small glyph
// keeps its contrast on top of its own wash.
func glyph(_ state: String) -> String {
    if state == "run" { return "#93C5FD" }
    if state == "wait" { return "#FDBA74" }
    return "#86EFAC"
}

// Chrome that carries no agent state. `slab` is the resting row, `slabFocus` the
// row you are on; a state wash layers on top of a slab rather than replacing it,
// so an idle row and a working row share a shape. `ink` / `dim` replace
// .primary / .secondary — see the note above.
func chrome(_ part: String) -> String {
    if part == "slab" { return "#1B222B" }
    if part == "slabFocus" { return "#1E2C3C" }
    if part == "ink" { return "#E6EAF0" }
    if part == "capsule" { return "#252E39" }
    if part == "focus" { return "#60A5FA" }
    if part == "pin" { return "#FBBF24" }
    if part == "subFill" { return "#1E40AF" }
    if part == "subText" { return "#DBEAFE" }
    return "#8B97A6"
}
// <<< conductor palette <<<
