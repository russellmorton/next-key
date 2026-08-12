local source = debug.getinfo(1, "S").source:sub(2)
local test_dir = source:match("(.*/)") or "./"

local callbacks = {}
local timers = {}
local commands = {}
local physical = {}

local function fake_timer(callback, options)
  local timer = {
    callback = callback,
    timeout = options.timeout,
    enabled = true,
  }
  function timer:set_enabled(value) self.enabled = value == true end
  function timer:is_enabled() return self.enabled end
  function timer:set_timeout(value) self.timeout = value end
  function timer:fire()
    if self.enabled then self.callback() end
  end
  timers[#timers + 1] = timer
  return timer
end

hl = {
  timer = fake_timer,
  is_key_down = function(key) return physical[key] == true end,
  get_active_monitor = function() return { name = "HDMI-A-2" } end,
  exec_cmd = function(command) commands[#commands + 1] = command end,
  on = function(name, callback)
    callbacks[name] = callback
    return { remove = function() end }
  end,
}

dofile(test_dir .. "../hypr/shortcut-hints.lua")

assert(#timers == 1)
local settle = timers[1]
assert(settle.timeout == 1 and not settle.enabled)

local key_names = {
  [37] = "Control_L",
  [50] = "Shift_L",
  [64] = "Alt_L",
  [133] = "Super_L",
}

-- Hyprland invokes the observer before updating hl.is_key_down state.
local function emit(keycode, state)
  callbacks["input.keyboard.key"](keycode, 0, state)
  local name = key_names[keycode]
  if name and state ~= 2 then physical[name] = state == 1 end
end

local function settle_event()
  settle:fire()
  assert(not settle.enabled)
end

emit(133, 1)
assert(#commands == 0)
settle_event()
assert(commands[#commands]:match("next%-key show 'SUPER' 'HDMI%-A%-2'"))

emit(50, 1)
settle_event()
assert(commands[#commands]:match("next%-key update 'SUPER SHIFT'"))
emit(50, 0)
settle_event()
assert(commands[#commands]:match("next%-key update 'SUPER'"))

emit(41, 1)
settle_event()
assert(commands[#commands]:match("next%-key hide$"))
local after_action = #commands
emit(133, 0)
settle_event()
assert(#commands == after_action)

-- With instant reveal, a fast shortcut shows and then immediately hides.
emit(133, 1)
settle_event()
assert(commands[#commands]:match("next%-key show 'SUPER' 'HDMI%-A%-2'"))
emit(36, 1)
settle_event()
assert(commands[#commands]:match("next%-key hide$"))
emit(133, 0)
settle_event()
assert(#commands == after_action + 2)

-- Repeat events are dropped, while config reload is one atomic UI message.
emit(133, 2)
assert(not settle.enabled)
callbacks["config.reloaded"]()
assert(commands[#commands]:match("next%-key reload$"))

print("observer: ok")
