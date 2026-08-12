local source = debug.getinfo(1, "S").source
local script_path = source:sub(1, 1) == "@" and source:sub(2) or source
local script_dir = script_path:match("(.*/)") or ""
local State = dofile(script_dir .. "ShortcutHintsState.lua")

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", "'\"'\"'") .. "'"
end

local function send_ipc(method, ...)
  local command = { "omarchy-shell", "-q", "next-key", method }
  for index = 1, select("#", ...) do
    command[#command + 1] = shell_quote(select(index, ...))
  end
  hl.exec_cmd(table.concat(command, " "))
end

local function key_down(key)
  local ok, down = pcall(hl.is_key_down, key)
  return ok and down == true
end

local function current_modifiers()
  return {
    super = key_down("Super_L") or key_down("Super_R"),
    shift = key_down("Shift_L") or key_down("Shift_R"),
    ctrl = key_down("Control_L") or key_down("Control_R"),
    alt = key_down("Alt_L") or key_down("Alt_R"),
  }
end

local function active_monitor_name()
  local ok, monitor = pcall(hl.get_active_monitor)
  if not ok or monitor == nil then return "" end
  return tostring(monitor.name or "")
end

local machine
local pending_key_event

-- input.keyboard.key is emitted just before Hyprland updates the pressed-key
-- set used by hl.is_key_down(). Hold one event until the next event-loop turn
-- (or the next key event) so every transition sees the post-event logical
-- modifier state. This is event-driven deferral, not input polling.
local function flush_pending_key_event()
  if not pending_key_event then return end
  local event = pending_key_event
  pending_key_event = nil
  machine:handle_key(event.keycode, event.state, current_modifiers())
end

local settle_timer
settle_timer = hl.timer(function()
  settle_timer:set_enabled(false)
  flush_pending_key_event()
end, { timeout = 1, type = "repeat" })
settle_timer:set_enabled(false)

machine = State.new({
  initial_modifiers = current_modifiers(),
  on_show = function(modifiers)
    send_ipc("show", modifiers, active_monitor_name())
  end,
  on_update = function(modifiers)
    send_ipc("update", modifiers, active_monitor_name())
  end,
  on_hide = function()
    send_ipc("hide")
  end,
  on_reload = function()
    send_ipc("reload")
  end,
})

hl.on("input.keyboard.key", function(keycode, _, key_state)
  -- The current snapshot now includes the preceding queued event but not this
  -- new one, so flush before replacing it. Repeats are never queued.
  settle_timer:set_enabled(false)
  flush_pending_key_event()
  if key_state == 2 then return end

  pending_key_event = { keycode = keycode, state = key_state }
  settle_timer:set_timeout(1)
  settle_timer:set_enabled(true)
end)

hl.on("config.reloaded", function()
  settle_timer:set_enabled(false)
  pending_key_event = nil
  machine:config_reloaded(current_modifiers())
end)
