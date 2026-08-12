var MODIFIER_ORDER = ["SUPER", "SHIFT", "CTRL", "ALT"]
var BRANCH_ORDER = ["SHIFT", "CTRL", "ALT"]

function trim(value) {
  return String(value === undefined || value === null ? "" : value)
    .replace(/^\s+|\s+$/g, "")
}

function normalizedModifier(token) {
  var value = trim(token).toUpperCase()
  if (value === "CONTROL") return "CTRL"
  if (value === "META" || value === "WIN" || value === "MOD4") return "SUPER"
  return MODIFIER_ORDER.indexOf(value) === -1 ? "" : value
}

function normalizeModifiers(value) {
  var source = Array.isArray(value) ? value : trim(value).split(/[+\s]+/)
  var present = {}

  for (var i = 0; i < source.length; i++) {
    var modifier = normalizedModifier(source[i])
    if (modifier) present[modifier] = true
  }

  var result = []
  for (var j = 0; j < MODIFIER_ORDER.length; j++) {
    if (present[MODIFIER_ORDER[j]]) result.push(MODIFIER_ORDER[j])
  }
  return result
}

function modifierKey(value) {
  return normalizeModifiers(value).join(" ")
}

function usefulDescription(value) {
  var description = trim(value)
  if (!description || description === "-" || description === "—") return false
  return !/^(?:hidden|internal)(?:\s*[:\-]|$)/i.test(description)
}

function excludedKey(value) {
  var key = trim(value)
  var upper = key.toUpperCase()
  return !key
    || upper.indexOf("XF86") === 0
    || upper.indexOf("MOUSE") !== -1
    || /^MOUSE_(?:UP|DOWN)$/i.test(key)
    || /^CODE:[0-9]+$/i.test(key)
}

// omarchy-menu-keybindings --print emits its normalized display records as:
//   SUPER SHIFT + B                  → Browser
// Parsing stops here deliberately: Omarchy remains responsible for resolving
// unbinds, Lua/code bindings, aliases, layouts, and broken hyprctl output.
function parseLine(line) {
  var match = String(line || "").match(/^\s*(.*?)\s*(?:→|->)\s*(.*?)\s*$/)
  if (!match) return null

  var combo = trim(match[1])
  var description = trim(match[2])
  var separator = combo.lastIndexOf(" + ")
  if (separator < 0) return null

  var modifiers = normalizeModifiers(combo.substring(0, separator))
  var key = trim(combo.substring(separator + 3))
  if (modifiers.indexOf("SUPER") === -1 || excludedKey(key) || !usefulDescription(description))
    return null

  return {
    modifiers: modifiers,
    modifierKey: modifiers.join(" "),
    key: key,
    description: description
  }
}

function parseBindings(output) {
  var lines = String(output || "").split(/\r?\n/)
  var records = []
  var seen = {}

  for (var i = 0; i < lines.length; i++) {
    var record = parseLine(lines[i])
    if (!record) continue

    // One hint per physical chord. Omarchy's normalized ordering decides
    // which description wins if upstream reports duplicate aliases.
    var signature = record.modifierKey + "\u001f" + record.key.toUpperCase()
    if (seen[signature]) continue
    seen[signature] = true
    records.push(record)
  }

  return records
}

function groupBindings(records) {
  var groups = {}
  var source = Array.isArray(records) ? records : []
  for (var i = 0; i < source.length; i++) {
    var key = modifierKey(source[i].modifiers)
    if (!groups[key]) groups[key] = []
    groups[key].push(source[i])
  }
  return groups
}

function bindingsFor(groups, modifiers) {
  var records = groups && groups[modifierKey(modifiers)]
  return Array.isArray(records) ? records.slice() : []
}

// Omarchy's default application layer uses SUPER SHIFT with letter keys,
// RETURN, and SLASH. Promote those normalized records into the initial SUPER
// view without guessing commands or maintaining a second binding parser.
function isApplicationBinding(record) {
  if (!record || modifierKey(record.modifiers) !== "SUPER SHIFT") return false
  var key = trim(record.key).toUpperCase()
  return /^[A-Z]$/.test(key) || key === "RETURN" || key === "SLASH"
}

function applicationSortKey(record) {
  var key = trim(record && record.key).toUpperCase()
  if (/^[A-Z]$/.test(key)) return "0" + key
  if (key === "RETURN") return "1"
  if (key === "SLASH") return "2"
  return "3" + key
}

function promotedApplications(groups) {
  var shifted = bindingsFor(groups, "SUPER SHIFT")
  var applications = []

  for (var i = 0; i < shifted.length; i++) {
    if (!isApplicationBinding(shifted[i])) continue
    applications.push({
      modifiers: shifted[i].modifiers.slice(),
      modifierKey: shifted[i].modifierKey,
      key: shifted[i].key,
      displayKey: "SHIFT+" + shifted[i].key,
      description: shifted[i].description,
      promoted: true
    })
  }

  applications.sort(function(left, right) {
    var leftKey = applicationSortKey(left)
    var rightKey = applicationSortKey(right)
    return leftKey < rightKey ? -1 : (leftKey > rightKey ? 1 : 0)
  })
  return applications
}

function prioritizeApplications(records) {
  var source = Array.isArray(records) ? records : []
  var applications = []
  var remaining = []

  for (var i = 0; i < source.length; i++) {
    if (isApplicationBinding(source[i])) applications.push(source[i])
    else remaining.push(source[i])
  }

  applications.sort(function(left, right) {
    var leftKey = applicationSortKey(left)
    var rightKey = applicationSortKey(right)
    return leftKey < rightKey ? -1 : (leftKey > rightKey ? 1 : 0)
  })
  return applications.concat(remaining)
}

function bindingsForView(groups, modifiers) {
  var current = bindingsFor(groups, modifiers)
  var key = modifierKey(modifiers)
  if (key === "SUPER") return promotedApplications(groups).concat(current)
  if (key === "SUPER SHIFT") return prioritizeApplications(current)
  return current
}

function branchCounts(groups, modifiers) {
  var current = normalizeModifiers(modifiers)
  var counts = []

  for (var i = 0; i < BRANCH_ORDER.length; i++) {
    var branch = BRANCH_ORDER[i]
    if (current.indexOf(branch) !== -1) continue
    var next = current.concat([branch])
    var count = bindingsFor(groups, next).length
    if (count > 0) counts.push({ modifier: branch, count: count })
  }

  return counts
}

function cappedBindings(records, limit) {
  var source = Array.isArray(records) ? records : []
  var max = Math.max(0, Math.floor(Number(limit) || 0))
  return {
    visible: source.slice(0, max),
    hiddenCount: Math.max(0, source.length - max)
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    MODIFIER_ORDER: MODIFIER_ORDER,
    normalizeModifiers: normalizeModifiers,
    modifierKey: modifierKey,
    usefulDescription: usefulDescription,
    excludedKey: excludedKey,
    parseLine: parseLine,
    parseBindings: parseBindings,
    groupBindings: groupBindings,
    bindingsFor: bindingsFor,
    isApplicationBinding: isApplicationBinding,
    promotedApplications: promotedApplications,
    prioritizeApplications: prioritizeApplications,
    bindingsForView: bindingsForView,
    branchCounts: branchCounts,
    cappedBindings: cappedBindings
  }
}
