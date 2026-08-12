local source = debug.getinfo(1, "S").source:sub(2)
local test_dir = source:match("(.*/)") or "./"
local State = dofile(test_dir .. "../hypr/ShortcutHintsState.lua")

local function mods(super, shift, ctrl, alt)
  return { super = super, shift = shift, ctrl = ctrl, alt = alt }
end

local events = {}
local machine = State.new({
  on_show = function(value) events[#events + 1] = "show:" .. value end,
  on_update = function(value) events[#events + 1] = "update:" .. value end,
  on_hide = function() events[#events + 1] = "hide" end,
  on_reload = function() events[#events + 1] = "reload" end,
})

-- Super reveals immediately, modifiers refine the view, and release hides it.
machine:handle_key(133, 1, mods(true, false, false, false))
assert(machine.state == "VISIBLE" and events[#events] == "show:SUPER")
machine:handle_key(50, 1, mods(true, true, false, false))
assert(events[#events] == "update:SUPER SHIFT")
machine:handle_key(37, 1, mods(true, true, true, false))
assert(events[#events] == "update:SUPER SHIFT CTRL")
machine:handle_key(50, 0, mods(true, false, true, false))
assert(events[#events] == "update:SUPER CTRL")
machine:handle_key(133, 0, mods(false, false, true, false))
assert(machine.state == "IDLE" and events[#events] == "hide")

-- A real shortcut hides the immediately visible overlay and suppresses it.
local event_count = #events
machine:handle_key(133, 1, mods(true, false, false, false))
assert(events[#events] == "show:SUPER")
machine:handle_key(36, 1, mods(true, false, false, false))
assert(machine.state == "SUPPRESSED" and events[#events] == "hide")
assert(#events == event_count + 2)
machine:handle_key(36, 2, mods(true, false, false, false))
assert(#events == event_count + 2)
machine:handle_key(133, 0, mods(false, false, false, false))
assert(machine.state == "IDLE" and #events == event_count + 2)

-- An action after reveal hides once and stays suppressed until final release.
machine:handle_key(133, 1, mods(true, false, false, false))
machine:handle_key(41, 1, mods(true, false, false, false))
assert(machine.state == "SUPPRESSED" and events[#events] == "hide")
local hidden_count = #events
machine:handle_key(50, 1, mods(true, true, false, false))
machine:handle_key(50, 0, mods(true, false, false, false))
assert(#events == hidden_count)
machine:handle_key(133, 0, mods(false, false, false, false))
assert(machine.state == "IDLE" and #events == hidden_count)

-- Repeats do not alter state, and a reload atomically resets/reloads the UI.
machine:handle_key(133, 2, mods(true, false, false, false))
assert(machine.state == "IDLE")
machine:handle_key(133, 1, mods(true, false, false, false))
machine:config_reloaded(mods(true, false, false, false))
assert(machine.state == "IDLE" and events[#events] == "reload")

-- Pressing both sides of a modifier is still a modifier event, not an action.
machine:handle_key(133, 0, mods(false, false, false, false))
machine:handle_key(133, 1, mods(true, false, false, false))
machine:handle_key(134, 1, mods(true, false, false, false))
assert(machine.state == "VISIBLE")

print("state-machine: ok")
