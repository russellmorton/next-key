# Repository Guidelines

## Project Structure & Module Organization

`ShortcutHints.qml` is the persistent NextKey Quickshell overlay entry point, while `ShortcutModel.js` parses and groups normalized Omarchy bindings. Reusable visual elements live in `components/`. Hyprland observation and state transitions belong in `hypr/`; keep display-independent logic in `hypr/ShortcutHintsState.lua`. Installation lifecycle scripts are in `bin/`. Automated checks and fixtures live in `tests/`. Treat `SPEC.md` as the behavioral contract and `manifest.json` as the plugin registration source.

## Build, Test, and Development Commands

This plugin has no compilation step. Run the relevant checks from the repository root:

```bash
node tests/shortcut-model.js       # binding parsing and grouping
lua tests/state-machine.lua        # core interaction transitions
lua tests/observer.lua             # Hyprland event integration
tests/hooks.sh                     # idempotent install/uninstall behavior
luac -p hypr/*.lua                 # Lua syntax validation
qmllint -I /usr/share/omarchy/shell ShortcutHints.qml components/*.qml
omarchy plugin validate .          # Quattro manifest/plugin validation
```

Run all available checks before submitting changes. Some validation commands require an Omarchy Quattro development machine.

## Coding Style & Naming Conventions

Use two-space indentation in QML, JavaScript, Lua, and shell scripts. Follow the existing semicolon-free JavaScript style and keep QML components declarative. Name QML components in PascalCase (`ModifierChip.qml`), Lua modules by their existing convention, and executable scripts with lowercase kebab-case (`install-hook`). Shell scripts should use `set -euo pipefail`, quote expansions, and avoid broad filesystem operations.

Keep input handling observational and event-driven. Do not add replacement keybindings, shortcut execution, polling, or `/dev/input` access. Consume `omarchy-menu-keybindings --print` rather than implementing another Hyprland binding parser.

## Testing Guidelines

Place language-specific tests under `tests/` and reusable sample output under `tests/fixtures/`. Add regression coverage for modifier parsing, branch counts, duplicate filtering, immediate display, suppression, reloads, and hook idempotency when those areas change. For visual changes, manually verify focus, pointer pass-through outside explicit controls, active-monitor placement, and the acceptance matrix in `SPEC.md`.

## Commit & Pull Request Guidelines

The repository has no established commit history yet. Use concise imperative subjects, preferably Conventional Commit prefixes such as `feat:`, `fix:`, `test:`, or `docs:`. Pull requests should explain behavior changes, list commands run, note tested Omarchy/Hyprland versions, and link relevant issues. Include screenshots or a short recording for overlay changes, and call out any installer or user-configuration impact explicitly.
