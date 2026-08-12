local StateMachine = {}
StateMachine.__index = StateMachine

local MODIFIER_KEYCODES = {
  [37] = true,  -- Control_L
  [50] = true,  -- Shift_L
  [62] = true,  -- Shift_R
  [64] = true,  -- Alt_L
  [105] = true, -- Control_R
  [108] = true, -- Alt_R / ISO_Level3_Shift
  [133] = true, -- Super_L
  [134] = true, -- Super_R
}

local function noop() end

local function copy_modifiers(modifiers)
  modifiers = modifiers or {}
  return {
    super = modifiers.super == true,
    shift = modifiers.shift == true,
    ctrl = modifiers.ctrl == true,
    alt = modifiers.alt == true,
  }
end

local function modifiers_changed(left, right)
  return left.super ~= right.super
    or left.shift ~= right.shift
    or left.ctrl ~= right.ctrl
    or left.alt ~= right.alt
end

local function modifier_key(modifiers)
  local parts = {}
  if modifiers.super then parts[#parts + 1] = "SUPER" end
  if modifiers.shift then parts[#parts + 1] = "SHIFT" end
  if modifiers.ctrl then parts[#parts + 1] = "CTRL" end
  if modifiers.alt then parts[#parts + 1] = "ALT" end
  return table.concat(parts, " ")
end

function StateMachine.new(options)
  options = options or {}
  local self = setmetatable({}, StateMachine)
  self.state = "IDLE"
  self.modifiers = copy_modifiers(options.initial_modifiers)
  self.visible_modifier_key = ""
  self.on_show = options.on_show or noop
  self.on_update = options.on_update or noop
  self.on_hide = options.on_hide or noop
  self.on_reload = options.on_reload or noop
  return self
end

function StateMachine:show()
  self.state = "VISIBLE"
  self.visible_modifier_key = modifier_key(self.modifiers)
  self.on_show(self.visible_modifier_key)
end

function StateMachine:suppress()
  if self.state == "VISIBLE" then
    self.on_hide()
  end
  self.state = "SUPPRESSED"
  self.visible_modifier_key = ""
end

function StateMachine:release_super()
  if self.state == "VISIBLE" then
    self.on_hide()
  end
  self.state = "IDLE"
  self.visible_modifier_key = ""
end

function StateMachine:handle_key(keycode, key_state, current_modifiers)
  -- Hyprland: 0 = release, 1 = press, 2 = repeat.
  if key_state == 2 then return end

  local previous = self.modifiers
  local current = copy_modifiers(current_modifiers)
  self.modifiers = current

  if not current.super then
    self:release_super()
    return
  end

  local is_modifier = MODIFIER_KEYCODES[tonumber(keycode)] == true
    or modifiers_changed(previous, current)

  if self.state == "IDLE" then
    if key_state == 1 and not previous.super and current.super and is_modifier then
      self:show()
    end
    return
  end

  if self.state == "SUPPRESSED" then return end

  if key_state == 1 and not is_modifier then
    self:suppress()
    return
  end

  if self.state == "VISIBLE" and is_modifier then
    local next_key = modifier_key(current)
    if next_key ~= self.visible_modifier_key then
      self.visible_modifier_key = next_key
      self.on_update(next_key)
    end
  end
end

function StateMachine:config_reloaded(current_modifiers)
  self.state = "IDLE"
  self.visible_modifier_key = ""
  self.modifiers = copy_modifiers(current_modifiers)
  -- The UI handles hide + binding reload together, keeping reload to one IPC.
  self.on_reload()
end

return {
  new = StateMachine.new,
  modifier_key = modifier_key,
  modifier_keycodes = MODIFIER_KEYCODES,
}
