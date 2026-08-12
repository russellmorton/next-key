const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const Model = require("../ShortcutModel.js")

const fixture = fs.readFileSync(path.join(__dirname, "fixtures/keybindings.txt"), "utf8")
const records = Model.parseBindings(fixture)
const groups = Model.groupBindings(records)

assert.deepEqual(Model.normalizeModifiers("CTRL + SUPER SHIFT"), ["SUPER", "SHIFT", "CTRL"])
assert.equal(Model.modifierKey(["ALT", "SUPER"]), "SUPER ALT")

assert.deepEqual(records.map(record => `${record.modifierKey}|${record.key}|${record.description}`), [
  "SUPER|K|Keybindings",
  "SUPER|RETURN|Terminal",
  "SUPER SHIFT|B|Browser",
  "SUPER CTRL|A|Audio",
  "SUPER SHIFT CTRL|R|Clear reminders",
  "SUPER ALT|F|Full width"
])

assert.equal(Model.bindingsFor(groups, "SUPER").length, 2)
assert.equal(Model.bindingsFor(groups, "SUPER SHIFT")[0].description, "Browser")
assert.equal(Model.isApplicationBinding(Model.bindingsFor(groups, "SUPER SHIFT")[0]), true)
assert.equal(Model.isApplicationBinding(Model.parseLine("SUPER SHIFT + BACKSPACE → Toggle gaps")), false)
assert.deepEqual(Model.bindingsForView(groups, "SUPER").map(record => [record.displayKey || record.key, record.description]), [
  ["SHIFT+B", "Browser"],
  ["K", "Keybindings"],
  ["RETURN", "Terminal"]
])
const prioritizedGroups = Model.groupBindings(Model.parseBindings([
  "SUPER + K → Keybindings",
  "SUPER SHIFT + C → Calendar",
  "SUPER SHIFT + A → ChatGPT",
  "SUPER SHIFT + BACKSPACE → Toggle gaps"
].join("\n")))
assert.deepEqual(Model.bindingsForView(prioritizedGroups, "SUPER").map(record => record.displayKey || record.key), [
  "SHIFT+A", "SHIFT+C", "K"
])
assert.deepEqual(Model.bindingsForView(prioritizedGroups, "SUPER SHIFT").map(record => record.displayKey || record.key), [
  "A", "C", "BACKSPACE"
])
assert.deepEqual(Model.branchCounts(groups, "SUPER"), [
  { modifier: "SHIFT", count: 1 },
  { modifier: "CTRL", count: 1 },
  { modifier: "ALT", count: 1 }
])
assert.deepEqual(Model.branchCounts(groups, "SUPER SHIFT"), [
  { modifier: "CTRL", count: 1 }
])
assert.deepEqual(Model.cappedBindings(Model.bindingsFor(groups, "SUPER"), 1), {
  visible: [records[0]],
  hiddenCount: 1
})

assert.equal(Model.parseLine("SUPER + SPACE -> Omarchy menu").key, "SPACE")
assert.equal(Model.parseLine("SUPER + XF86AudioPlay → Media"), null)
assert.equal(Model.parseLine("CTRL + A → No Super"), null)

console.log("shortcut-model: ok")
