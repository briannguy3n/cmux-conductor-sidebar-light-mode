// >>> conductor palette >>>
// Light palette — the file installed as `conductor`. install.sh builds the dark
// twin (`conductor-dark`) by swapping this block for files/palette-dark.swift,
// so the view below stays single-source and the two variants cannot drift.
// The sidebar DSL exposes no colorScheme, so the palette cannot branch on the
// appearance; the bottom-left switcher activates the other file instead.
//
// Every row slab, pill and neutral ink is painted from this block. The bar's own
// ground is not: the host sizes this view to its content, so a filled rectangle
// would stop under the footer. cmux's `app.appearance` owns the ground, and the
// switcher sets it in step with the palette — which is also why the two must
// agree. The sidebar mounts as real SwiftUI in the cmux window, so `.primary` /
// `.secondary` resolve against that window; the palette states them outright
// instead, so a row never depends on which appearance won.
//
// theme() carries the variant's identity: the appearance the switcher moves to,
// and how that button reads.
func theme(_ key: String) -> String {
    if key == "next" { return "dark" }
    if key == "icon" { return "moon.fill" }
    return "Dark"
}

func statusFill(_ label: String) -> String {
    return label == "RUNNING" ? "#DBEAFE" : (label == "WAITING" ? "#FFEDD5" : "#DCFCE7")
}

func statusText(_ label: String) -> String {
    return label == "RUNNING" ? "#1E40AF" : (label == "WAITING" ? "#9A3412" : "#166534")
}

func prFill(_ status: String, _ stale: Bool) -> String {
    if stale { return "#FFEDD5" }
    return status == "merged" ? "#EDE9FE" : (status == "closed" ? "#FEE2E2" : "#DCFCE7")
}

func prText(_ status: String, _ stale: Bool) -> String {
    if stale { return "#9A3412" }
    return status == "merged" ? "#5B21B6" : (status == "closed" ? "#991B1B" : "#166534")
}

// Row wash. Blue while the tab works, orange while it is blocked on you, green
// once it is done. All three read louder than plain focus, so focus never hides
// a tab that wants something from you.
func rowWash(_ done: Bool, _ waiting: Bool) -> String {
    if waiting { return "#EA580C" }
    return done ? "#16A34A" : "#2563EB"
}

func rowTint(_ active: Bool, _ focused: Bool) -> Double {
    if active && focused { return 0.22 }
    if active { return 0.16 }
    return focused ? 0.10 : 0.0
}

// Per-state accent: the row's left bar and its dot.
func accent(_ state: String) -> String {
    if state == "run" { return "#2563EB" }
    if state == "wait" { return "#EA580C" }
    return "#16A34A"
}

// Row glyph (spinner / terminal icon). Deeper than accent() so a small glyph
// keeps its contrast on top of its own wash.
func glyph(_ state: String) -> String {
    if state == "run" { return "#1D4ED8" }
    if state == "wait" { return "#C2410C" }
    return "#15803D"
}

// Chrome that carries no agent state. `slab` is the resting row, `slabFocus` the
// row you are on; a state wash layers on top of a slab rather than replacing it,
// so an idle row and a working row share a shape. `ink` / `dim` replace
// .primary / .secondary — see the note above.
func chrome(_ part: String) -> String {
    if part == "slab" { return "#EEF0F4" }
    if part == "slabFocus" { return "#E3E8F0" }
    if part == "ink" { return "#111827" }
    if part == "capsule" { return "#E4E7EB" }
    if part == "focus" { return "#2563EB" }
    if part == "pin" { return "#B45309" }
    if part == "subFill" { return "#BFDBFE" }
    if part == "subText" { return "#1E40AF" }
    return "#6B7280"
}
// <<< conductor palette <<<

func statusLabel(_ label: String) -> String {
    return label.hasPrefix("RUNNING") ? "RUNNING" : (label.hasPrefix("WAITING") ? "WAITING" : "READY")
}

// The interpreter drops `== nil` / `!= nil`, so collapse state is read from the
// interpolated description instead. A nil description interpolates to something
// that does not contain the marker, which is the expanded case.
func isCollapsed(_ d: String) -> Bool {
    return d.contains("collapsed")
}

func isExpanded(_ d: String) -> Bool {
    return d.contains("collapsed") ? false : true
}

// Self-drawn spinner (clock-driven, keeps spinning while unfocused)
func spinner(_ sec: Int) -> String {
    let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    return frames[sec % 10]
}

// A tab is working when the workspace label carries its run: marker.
func isRunning(_ label: String, _ id: String) -> Bool {
    return label.contains("run:\(id)")
}

// A tab is done when it finished and you have not looked at it yet — the
// answer is sitting there waiting for you. A tab is waiting when the agent is
// blocked on a question. push_ws writes exactly one marker per tab, so run:,
// done: and waiting: are mutually exclusive.
func isDone(_ label: String, _ id: String) -> Bool {
    return label.contains("done:\(id)")
}

func isWaiting(_ label: String, _ id: String) -> Bool {
    return label.contains("waiting:\(id)")
}

// Live subagent count for one tab — a Task fan-out or a workflow in flight.
// cmux-status.sh caps the count at 9, so a single digit always matches exactly.
func hasSubs(_ label: String, _ id: String) -> Bool {
    return label.contains("sub:\(id):")
}

func subCount(_ label: String, _ id: String) -> String {
    if label.contains("sub:\(id):9") { return "9+" }
    if label.contains("sub:\(id):8") { return "8" }
    if label.contains("sub:\(id):7") { return "7" }
    if label.contains("sub:\(id):6") { return "6" }
    if label.contains("sub:\(id):5") { return "5" }
    if label.contains("sub:\(id):4") { return "4" }
    if label.contains("sub:\(id):3") { return "3" }
    if label.contains("sub:\(id):2") { return "2" }
    return "1"
}

VStack(alignment: .leading, spacing: 0) {
    HStack {
        Text("Workspaces").font(.title).bold().foregroundColor(chrome("ink"))
        Spacer()
    }.padding(6)
    Spacer().frame(height: 8)
    ScrollView {
        VStack(alignment: .leading, spacing: 2) {
            Reorderable(workspaces, move: "workspace.reorder") { w in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Button(action: { cmux("workspace.action", action: isCollapsed("\(w.description)") ? "clear_description" : "set_description", workspace_id: w.id, description: "collapsed") }) {
                            Image(systemName: isCollapsed("\(w.description)") ? "chevron.right" : "chevron.down")
                                .imageScale(.small)
                                .foregroundColor(chrome("dim"))
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        Image(systemName: "folder.fill")
                            .imageScale(.small)
                            .foregroundColor(w.selected ? chrome("focus") : chrome("dim"))
                        Text(w.title)
                            .font(.title3).bold()
                            .foregroundColor(chrome("ink"))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                        Text("\(w.tabCount)")
                            .font(.system(size: 10))
                            .foregroundColor(chrome("dim"))
                            .frame(width: w.tabCount > 9 ? 24 : 18, height: 18)
                            .background {
                                Capsule().fill(chrome("capsule"))
                            }
                            .fixedSize()
                        if w.pinned {
                            Image(systemName: "pin.fill")
                                .imageScale(.small)
                                .foregroundColor(chrome("pin"))
                                .rotationEffect(.degrees(45))
                        }
                        Spacer(minLength: 3)
                        if let p = w.progress {
                            Text(statusLabel("\(p.label)"))
                                .font(.system(size: 11)).bold()
                                .foregroundColor(statusText(statusLabel("\(p.label)")))
                                .padding(2)
                                .background(statusFill(statusLabel("\(p.label)")))
                                .cornerRadius(7)
                                .fixedSize()
                        }
                        if let pr = w.pr {
                            Text("#\(pr.number)")
                                .font(.system(size: 11)).bold()
                                .foregroundColor(prText("\(pr.status)", pr.stale))
                                .padding(2)
                                .background(prFill("\(pr.status)", pr.stale))
                                .cornerRadius(7)
                                .fixedSize()
                        }
                        if w.index < 9 {
                            Text("⌘\(w.index + 1)")
                                .font(.system(size: 10))
                                .foregroundColor(chrome("dim"))
                                .fixedSize()
                        }
                        Button(action: { cmux("surface.create", workspace_id: w.id, focus: true) }) {
                            Image(systemName: "plus")
                                .imageScale(.small)
                                .foregroundColor(chrome("dim"))
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                    }
                    .padding(4)
                    .onTapGesture { cmux("workspace.select", workspace_id: w.id) }
                    .contextMenu {
                        Button("Rename…") { cmux("notification.create_for_caller", title: "cmux-rename", body: w.id) }
                        Button("Move to Top") { cmux("workspace.action", action: "move_top", workspace_id: w.id) }
                        Button("Move Up") { cmux("workspace.action", action: "move_up", workspace_id: w.id) }
                        Button("Move Down") { cmux("workspace.action", action: "move_down", workspace_id: w.id) }
                        Button(w.pinned ? "Unpin" : "Pin") { cmux("workspace.action", action: w.pinned ? "unpin" : "pin", workspace_id: w.id) }
                        Button("Mark as Read") { cmux("workspace.action", action: "mark_read", workspace_id: w.id) }
                        Button("New Tab") { cmux("surface.create", workspace_id: w.id, focus: true) }
                        Button("Close Workspace") { cmux("workspace.close", workspace_id: w.id) }
                    }
                    if isExpanded("\(w.description)") {
                        ForEach(w.tabs.prefix(12)) { t in
                            HStack(spacing: 6) {
                                // 3 + 6 (HStack spacing) + 3 keeps the icon at the
                                // same x as the plain 12pt indent it replaces.
                                Spacer().frame(width: 3)
                                if let p = w.progress {
                                    if isRunning("\(p.label)", "\(t.id)") {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(accent("run"))
                                            .frame(width: 3, height: 22)
                                    } else if isWaiting("\(p.label)", "\(t.id)") {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(accent("wait"))
                                            .frame(width: 3, height: 22)
                                    } else if isDone("\(p.label)", "\(t.id)") {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(accent("done"))
                                            .frame(width: 3, height: 22)
                                    } else {
                                        Spacer().frame(width: 3)
                                    }
                                } else {
                                    Spacer().frame(width: 3)
                                }
                                if let p = w.progress {
                                    if isRunning("\(p.label)", "\(t.id)") {
                                        Text(["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"][clock.second % 10])
                                            .font(.system(size: 16)).bold()
                                            .foregroundColor(glyph("run"))
                                            .frame(width: 16)
                                    } else if isWaiting("\(p.label)", "\(t.id)") {
                                        Image(systemName: "terminal")
                                            .imageScale(.small)
                                            .foregroundColor(glyph("wait"))
                                    } else if isDone("\(p.label)", "\(t.id)") {
                                        Image(systemName: "terminal")
                                            .imageScale(.small)
                                            .foregroundColor(glyph("done"))
                                    } else {
                                        Image(systemName: "terminal")
                                            .imageScale(.small)
                                            .foregroundColor(t.focused && w.selected ? chrome("focus") : chrome("dim"))
                                    }
                                } else {
                                    Image(systemName: "terminal")
                                        .imageScale(.small)
                                        .foregroundColor(t.focused && w.selected ? chrome("focus") : chrome("dim"))
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(t.title)
                                        .font(.title3)
                                        .foregroundColor(t.focused && w.selected ? chrome("ink") : chrome("dim"))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    if t.focused {
                                        if let m = w.latestMessage {
                                            Text("\(m)")
                                                .font(.footnote)
                                                .foregroundColor(chrome("dim"))
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                    }
                                }
                                Spacer(minLength: 0)
                                if let p = w.progress {
                                    if hasSubs("\(p.label)", "\(t.id)") {
                                        Text("⚙\(subCount("\(p.label)", "\(t.id)"))")
                                            .font(.system(size: 10)).bold()
                                            .foregroundColor(chrome("subText"))
                                            .padding(2)
                                            .background(chrome("subFill"))
                                            .cornerRadius(7)
                                            .fixedSize()
                                    }
                                    if p.label.contains("done:\(t.id)") {
                                        Circle().fill(accent("done")).frame(width: 7, height: 7).fixedSize()
                                    } else if p.label.contains("waiting:\(t.id)") {
                                        Circle().fill(accent("wait")).frame(width: 7, height: 7).fixedSize()
                                    }
                                }
                                if t.focused && w.selected {
                                    Button(action: { cmux("surface.close", surface_id: t.id) }) {
                                        Image(systemName: "xmark")
                                            .imageScale(.small)
                                            .foregroundColor(chrome("dim"))
                                    }
                                    .buttonStyle(.plain)
                                    .fixedSize()
                                }
                            }
                            .padding(6)
                            .background {
                                // Two layers: the opaque slab that gives every row
                                // the same body, then the state wash on top of it.
                                // The wash stays translucent so blue/orange/green
                                // read as a tint of the row, not a second shape.
                                if let p = w.progress {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 7)
                                            .fill(t.focused && w.selected ? chrome("slabFocus") : chrome("slab"))
                                        RoundedRectangle(cornerRadius: 7)
                                            .fill(rowWash(isDone("\(p.label)", "\(t.id)"), isWaiting("\(p.label)", "\(t.id)")))
                                            .opacity(rowTint(isRunning("\(p.label)", "\(t.id)") || isDone("\(p.label)", "\(t.id)") || isWaiting("\(p.label)", "\(t.id)"), t.focused && w.selected))
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(t.focused && w.selected ? chrome("slabFocus") : chrome("slab"))
                                }
                            }
                            .overlay {
                                if let p = w.progress {
                                    t.focused && w.selected
                                        ? AnyView(RoundedRectangle(cornerRadius: 7).stroke(rowWash(isDone("\(p.label)", "\(t.id)"), isWaiting("\(p.label)", "\(t.id)")), lineWidth: 1))
                                        : AnyView(EmptyView())
                                } else {
                                    t.focused && w.selected
                                        ? AnyView(RoundedRectangle(cornerRadius: 7).stroke(chrome("focus"), lineWidth: 1))
                                        : AnyView(EmptyView())
                                }
                            }
                            .onTapGesture {
                                cmux("workspace.select", workspace_id: w.id)
                                cmux("surface.focus", surface_id: t.id)
                                cmux("notification.create_for_caller", title: "cmux-seen", body: t.id)
                            }
                            .contextMenu {
                                Button("Close Tab") { cmux("surface.close", surface_id: t.id) }
                            }
                        }
                        if w.tabCount > 12 {
                            Text("+ \(w.tabCount - 12) more")
                                .font(.footnote).foregroundColor(chrome("dim"))
                                .padding(4)
                        }
                    }
                }
                .padding(2)
            }
        }
    }
    // Appearance switcher, under the list at the bottom left. The DSL has no
    // @State, so the choice cannot live in the sidebar: the button emits a magic
    // notification that cmux-rename-hook.sh intercepts, and the hook sets
    // cmux's `app.appearance` (that is what darkens the bar itself) and then
    // activates the matching palette file. Both settings persist, so the pick
    // survives a restart.
    Divider()
    HStack(spacing: 5) {
        Button(action: { cmux("notification.create_for_caller", title: "cmux-theme", body: theme("next")) }) {
            HStack(spacing: 4) {
                Image(systemName: theme("icon"))
                    .imageScale(.small)
                    .foregroundColor(chrome("dim"))
                Text(theme("label"))
                    .font(.system(size: 11))
                    .foregroundColor(chrome("dim"))
            }
            .padding(3)
        }
        .buttonStyle(.plain)
        .fixedSize()
        Spacer()
    }
    .padding(4)
}
// The host sizes this view to its content, so the bar's own ground is never
// ours to paint: a filled rectangle would stop under the footer and leave a
// seam. The switcher flips cmux's `app.appearance` instead, which repaints the
// whole window — bar, chrome and all — natively.
.frame(maxWidth: .infinity, alignment: .leading)
