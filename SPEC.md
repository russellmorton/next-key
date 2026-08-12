# NextKey — v1 Specification

## Goal

Provide a system-wide, observational “which-key” overlay for Omarchy Quattro.
Pressing `Super` shows the user's current `Super` shortcuts immediately. Adding or
removing `Shift`, `Ctrl`, or `Alt` filters the visible shortcuts immediately.
Existing Hyprland bindings remain the only shortcut execution path.

## Platform and boundaries

- Target Omarchy 4 / Quattro and its native Quickshell plugin system.
- Implement as a third-party, persistent overlay plugin; do not modify Omarchy
  core.
- Observe Hyprland keyboard press/release events; do not intercept input.
- Do not execute shortcuts, add replacement bindings, use submaps, poll input,
  or access `/dev/input`.
- Load the observer through one guarded, marked block in the user's
  `~/.config/hypr/bindings.lua`. A missing or broken plugin must not prevent
  Hyprland startup.
- Refuse installation cleanly when the Quattro plugin system or required
  Hyprland Lua APIs are unavailable.

## Components

1. A Hyprland Lua observer owns the interaction state machine, watches keyboard
   and config-reload events, determines the active modifier set and monitor,
   and sends only meaningful changes over Omarchy Shell IPC.
2. A keep-loaded Quickshell overlay receives observer messages, loads normalized
   bindings, filters them, and renders a transient non-interactive panel.
3. A testable JavaScript model parses and groups binding records and computes
   modifier-branch counts.
4. Idempotent install/uninstall hooks add or remove only the marked guarded
   loader block.

Exact API names and IPC shapes must follow the versions actually exposed by
current upstream Hyprland and Omarchy Quattro, even where they differ from the
initial plan.

Verified Hyprland 0.56 adaptation: `input.keyboard.key` is emitted immediately
before `hl.is_key_down`'s pressed-key set is updated, so the observer defers
each event by one event-loop tick using a disabled, self-stopping `repeat`
timer. This implementation-required 1 ms settle step is the only deferral; it
runs only in response to input and is never an idle polling loop.

## Binding source and filtering

- Load `omarchy-menu-keybindings --print` at plugin startup and reload it after
  Hyprland configuration reloads. Reuse its normalized output; do not implement
  a second Omarchy/Hyprland binding parser.
- Display described keyboard bindings containing `Super`.
- Exclude mouse bindings, XF86/media keys, hidden/internal records, unusable
  descriptions, and duplicate aliases.
- Group by the exact logical modifier set, with modifier order normalized as
  `SUPER`, `SHIFT`, `CTRL`, `ALT`.
- Show counts for available deeper modifier branches.
- Hyprland submaps are outside v1 scope.

## Interaction state machine

States: `IDLE`, `VISIBLE`, `SUPPRESSED`.

- First `Super` press: `IDLE -> VISIBLE`; show the exact modifier group on the
  active monitor immediately after Hyprland's state snapshot settles.
- Additional modifier press/release while visible: remain `VISIBLE` and update
  the group immediately.
- First non-modifier press while visible: transition to `SUPPRESSED` and hide
  immediately.
- While suppressed, ignore input until every `Super` key is released.
- Final `Super` release from any state: hide if needed and return to `IDLE`.
- Ignore repeated key-down events.
- Config reload requests a binding-model reload without changing shortcut
  execution.

Shell IPC occurs only for initial show, visible modifier changes, visible
action-key hide, final Super-release hide, and config reload.

## Overlay behavior

- Use Omarchy Shell theme tokens and the established overlay/OSD conventions.
- Render on the active monitor in a compact lower-right panel aligned with the
  outer edge of tiled windows.
- In the default `SUPER` view, promote Omarchy's normalized `SUPER SHIFT`
  application bindings ahead of direct `SUPER` actions. Preserve that
  app-first order in the exact `SUPER SHIFT` view, using the unprefixed action
  keys there.
- Use up to three columns and five rows, with a 40% maximum monitor width.
  Truncate oversized groups with a clickable `+ N more` control that expands
  the complete list without executing any shortcut. Keep the footer control
  present as `− show less` while expanded so its input region never goes empty
  during modifier backtracking.
- Each action contains a keycap and useful description. The footer shows
  available modifier branches and counts.
- Approximate motion: 100 ms fade/rise on show, 60–100 ms content crossfade,
  and 80 ms fade on hide.
- Never request keyboard focus, alter the active window, or block
  fullscreen/floating applications. Pointer input is accepted only over the
  explicit `+ N more` expansion control; the rest remains click-through.
  The control's input region must recover when modifier changes collapse an
  expanded view back to its five-row preview.

## Installation safety

The install hook must validate compatibility before changing configuration,
back up `bindings.lua`, append the marked loader at most once, validate the
resulting Lua, and reload Hyprland. If validation or reload fails, restore the
backup. The loader must guard file existence and protect plugin evaluation so
a removed or broken plugin cannot abort Hyprland configuration loading.

The uninstall hook removes only the exact marked block, is safe to run more
than once, validates the resulting Lua, and reloads Hyprland when available.

## Verification

Automated checks cover normalized binding parsing, filtering, grouping,
deduplication, branch counts, immediate appearance, modifier changes,
action-key suppression, final-Super release, repeat handling, and config reload.
Also run the available equivalents of:

```text
omarchy plugin validate
luac -p hypr/shortcut-hints.lua
qmllint ShortcutHints.qml
```

Runtime acceptance includes immediate initial reveal, live modifier
filtering, action execution with immediate hiding, custom/unbound/layout/code
bindings, config reload, active-monitor placement, fullscreen/floating windows,
rapid/repeated input, shell restart, and safe disable/removal.
