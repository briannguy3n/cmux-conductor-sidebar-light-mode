// Tuned for a light cmux theme. The sidebar DSL exposes no colorScheme, so the
// palette cannot branch on the appearance. Surfaces are therefore translucent,
// and each pill carries its own fill, so nothing depends on the sidebar ground.
func statusLabel(_ label: String) -> String {
    return label.hasPrefix("RUNNING") ? "RUNNING" : (label.hasPrefix("WAITING") ? "WAITING" : "READY")
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

VStack(alignment: .leading, spacing: 0) {
    HStack {
        Text("Workspaces").font(.title).bold()
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
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        Image(systemName: "folder.fill")
                            .imageScale(.small)
                            .foregroundColor(w.selected ? "#2563EB" : .secondary)
                        Text(w.title)
                            .font(.title3).bold()
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                        Text("\(w.tabCount)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: w.tabCount > 9 ? 24 : 18, height: 18)
                            .background {
                                Capsule().fill(.primary).opacity(0.08)
                            }
                            .fixedSize()
                        if w.pinned {
                            Image(systemName: "pin.fill")
                                .imageScale(.small)
                                .foregroundColor("#B45309")
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
                                .foregroundColor(.secondary)
                                .fixedSize()
                        }
                        Button(action: { cmux("surface.create", workspace_id: w.id, focus: true) }) {
                            Image(systemName: "plus")
                                .imageScale(.small)
                                .foregroundColor(.secondary)
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
                                            .fill("#2563EB")
                                            .frame(width: 3, height: 22)
                                    } else if isWaiting("\(p.label)", "\(t.id)") {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill("#EA580C")
                                            .frame(width: 3, height: 22)
                                    } else if isDone("\(p.label)", "\(t.id)") {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill("#16A34A")
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
                                            .foregroundColor("#1D4ED8")
                                            .frame(width: 16)
                                    } else if isWaiting("\(p.label)", "\(t.id)") {
                                        Image(systemName: "terminal")
                                            .imageScale(.small)
                                            .foregroundColor("#C2410C")
                                    } else if isDone("\(p.label)", "\(t.id)") {
                                        Image(systemName: "terminal")
                                            .imageScale(.small)
                                            .foregroundColor("#15803D")
                                    } else {
                                        Image(systemName: "terminal")
                                            .imageScale(.small)
                                            .foregroundColor(t.focused && w.selected ? "#2563EB" : .secondary)
                                    }
                                } else {
                                    Image(systemName: "terminal")
                                        .imageScale(.small)
                                        .foregroundColor(t.focused && w.selected ? "#2563EB" : .secondary)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(t.title)
                                        .font(.title3)
                                        .foregroundColor(t.focused && w.selected ? .primary : .secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    if t.focused {
                                        if let m = w.latestMessage {
                                            Text("\(m)")
                                                .font(.footnote)
                                                .foregroundColor(.secondary)
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
                                            .foregroundColor("#1E40AF")
                                            .padding(2)
                                            .background("#BFDBFE")
                                            .cornerRadius(7)
                                            .fixedSize()
                                    }
                                    if p.label.contains("done:\(t.id)") {
                                        Circle().fill("#16A34A").frame(width: 7, height: 7).fixedSize()
                                    } else if p.label.contains("waiting:\(t.id)") {
                                        Circle().fill("#EA580C").frame(width: 7, height: 7).fixedSize()
                                    }
                                }
                                if t.focused && w.selected {
                                    Button(action: { cmux("surface.close", surface_id: t.id) }) {
                                        Image(systemName: "xmark")
                                            .imageScale(.small)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .fixedSize()
                                }
                            }
                            .padding(6)
                            .background {
                                if let p = w.progress {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(rowWash(isDone("\(p.label)", "\(t.id)"), isWaiting("\(p.label)", "\(t.id)")))
                                        .opacity(rowTint(isRunning("\(p.label)", "\(t.id)") || isDone("\(p.label)", "\(t.id)") || isWaiting("\(p.label)", "\(t.id)"), t.focused && w.selected))
                                } else {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill("#2563EB")
                                        .opacity(t.focused && w.selected ? 0.1 : 0.0)
                                }
                            }
                            .overlay {
                                if let p = w.progress {
                                    t.focused && w.selected
                                        ? AnyView(RoundedRectangle(cornerRadius: 7).stroke(rowWash(isDone("\(p.label)", "\(t.id)"), isWaiting("\(p.label)", "\(t.id)")), lineWidth: 1))
                                        : AnyView(EmptyView())
                                } else {
                                    t.focused && w.selected
                                        ? AnyView(RoundedRectangle(cornerRadius: 7).stroke("#2563EB", lineWidth: 1))
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
                                .font(.footnote).foregroundColor(.secondary)
                                .padding(4)
                        }
                    }
                }
                .padding(2)
            }
        }
    }
}
