# NextKey

NextKey is a passive, system-wide “which-key” overlay for Omarchy Quattro. Press `Super`
to see the user's real Omarchy shortcuts immediately; add or remove `Shift`,
`Ctrl`, or `Alt` to filter them live.

The plugin never binds, intercepts, or executes a shortcut. Hyprland remains
the sole input and execution path. The observer only subscribes to Hyprland's
raw keyboard event, reads logical modifier state, and sends meaningful display
changes to the already-running Omarchy shell. There is no input polling,
background daemon, `/dev/input` access, or replacement submap.

## Requirements

- Omarchy 4 / Quattro with its Quickshell plugin system
- Hyprland 0.55 or newer with `input.keyboard.key`, `config.reloaded`, timers,
  `hl.is_key_down`, and active-monitor Lua APIs
- `omarchy-menu-keybindings`, `omarchy-shell`, `luac`, and Quickshell

The install hook checks the exact runtime APIs before changing configuration.
The observer defers each raw key event by one event-loop tick because current
Hyprland emits `input.keyboard.key` immediately before updating the state read
by `hl.is_key_down`. A disabled, self-stopping timer defers processing by the
required one event-loop tick (1 ms); there is no intentional reveal delay and
the timer remains disabled at idle.
Omarchy 3.x is intentionally unsupported.

## Install

```bash
omarchy plugin add https://github.com/russellmorton/next-key.git --enable
~/.config/omarchy/plugins/next-key/bin/install-hook
```

The second command adds one marked loader block to
`~/.config/hypr/bindings.lua`, after making a timestamped backup. It is safe to
run again. The loader checks that the plugin file exists and evaluates it with
`pcall`, so deleting or breaking the plugin cannot abort Hyprland startup.

The overlay loads bindings from:

```bash
omarchy-menu-keybindings --print
```

That command remains responsible for custom bindings, `unbind`, Lua and
`code:` bindings, layout resolution, duplicate cleanup, and Hyprland output
workarounds. The plugin only parses its normalized `COMBO → Description`
display records. A Hyprland config reload automatically refreshes the model.

## Uninstall

Run the uninstall hook before removing the plugin directory:

```bash
~/.config/omarchy/plugins/next-key/bin/uninstall-hook
omarchy plugin remove next-key
```

The hook removes only the marked block and is idempotent. If the directory was
already removed, the guarded loader is harmless; restore the plugin temporarily
or remove only the block between the two `next-key` markers.

## Behavior

- Press `Super`: the overlay appears immediately on Hyprland's active monitor.
- Continue into a normal `Super` shortcut: the overlay hides as soon as its
  action key is pressed.
- Add/remove `Shift`, `Ctrl`, or `Alt`: contents update immediately.
- Press a non-modifier action key: the overlay hides and stays suppressed until
  all Super keys are released; the existing Hyprland shortcut executes normally.
- Reload Hyprland: the overlay closes and reloads normalized bindings.

The default `SUPER` view promotes normalized `SUPER SHIFT` application
bindings, such as `SHIFT+A` for ChatGPT, ahead of direct `SUPER` actions. When
`Shift` is held, the same apps remain first with natural labels such as `A`.
The five-row preview expands when its `+ N more` control is clicked; the same
control becomes `− show less` while expanded.

The visual surface uses Omarchy's popup colors, border, typography, spacing,
and corner tokens. It has no keyboard focus; only the expansion control accepts
pointer input, while the rest of the overlay remains click-through.

## Development and checks

```bash
node tests/shortcut-model.js
lua tests/state-machine.lua
lua tests/observer.lua
tests/hooks.sh
luac -p hypr/shortcut-hints.lua hypr/ShortcutHintsState.lua
qmllint -I /usr/share/omarchy/shell ShortcutHints.qml components/*.qml
omarchy plugin validate .
```

See [SPEC.md](SPEC.md) for the complete v1 behavior and safety contract.
