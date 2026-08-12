import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "components"
import "ShortcutModel.js" as ShortcutModel

Item {
  id: root

  property bool opened: false
  property string targetMonitor: ""
  property string currentModifierKey: "SUPER"
  property var allBindings: []
  property var bindingGroups: ({})
  property var currentBindings: []
  property var visibleBindings: []
  property var modifierBranches: []
  property int hiddenBindingCount: 0
  property int overflowBindingCount: 0
  property bool expanded: false
  property bool moreHovered: false
  property real contentOpacity: 1
  readonly property int maximumRows: 5
  readonly property var currentModifiers: ShortcutModel.normalizeModifiers(currentModifierKey)

  function setModifierGroup(modifiers, animate) {
    currentModifierKey = ShortcutModel.modifierKey(modifiers) || "SUPER"
    expanded = false
    currentBindings = ShortcutModel.bindingsForView(bindingGroups, currentModifierKey)
    modifierBranches = ShortcutModel.branchCounts(bindingGroups, currentModifierKey)
    var capped = ShortcutModel.cappedBindings(
      currentBindings,
      columnCount(currentBindings.length) * maximumRows
    )
    visibleBindings = capped.visible
    hiddenBindingCount = capped.hiddenCount
    overflowBindingCount = capped.hiddenCount

    if (animate && opened) {
      contentOpacity = 0.35
      contentSettleTimer.restart()
    } else {
      contentOpacity = 1
    }
  }

  function expandBindings() {
    if (overflowBindingCount <= 0) return
    expanded = true
    visibleBindings = currentBindings.slice()
    hiddenBindingCount = 0
    contentOpacity = 0.35
    contentSettleTimer.restart()
  }

  function collapseBindings() {
    if (!expanded) return
    expanded = false
    var capped = ShortcutModel.cappedBindings(
      currentBindings,
      columnCount(currentBindings.length) * maximumRows
    )
    visibleBindings = capped.visible
    hiddenBindingCount = capped.hiddenCount
    overflowBindingCount = capped.hiddenCount
    contentOpacity = 0.35
    contentSettleTimer.restart()
  }

  function toggleExpandedBindings() {
    if (expanded) collapseBindings()
    else expandBindings()
  }

  function loadBindings(output) {
    var text = String(output || "")
    if (!text.trim()) return
    allBindings = ShortcutModel.parseBindings(text)
    bindingGroups = ShortcutModel.groupBindings(allBindings)
    setModifierGroup(currentModifierKey, false)
  }

  function reloadBindings() {
    if (!bindingProcess.running) bindingProcess.running = true
  }

  function showHints(modifiers, monitor) {
    targetMonitor = String(monitor || "")
    setModifierGroup(modifiers, false)
    opened = true
  }

  function updateHints(modifiers, monitor) {
    if (monitor) targetMonitor = String(monitor)
    setModifierGroup(modifiers, true)
  }

  function hideHints() {
    opened = false
    expanded = false
    moreHovered = false
    contentSettleTimer.stop()
    contentOpacity = 1
  }

  function reloadAndHide() {
    hideHints()
    reloadBindings()
  }

  function columnCount(bindingCount) {
    if (bindingCount > 8) return 3
    if (bindingCount > 4) return 2
    return 1
  }

  Timer {
    id: contentSettleTimer
    interval: 70
    repeat: false
    onTriggered: root.contentOpacity = 1
  }

  Process {
    id: bindingProcess
    command: ["omarchy-menu-keybindings", "--print"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loadBindings(text)
    }
  }

  IpcHandler {
    target: "next-key"

    function show(modifiers: string, monitor: string): string {
      root.showHints(modifiers, monitor)
      return "ok"
    }

    function update(modifiers: string, monitor: string): string {
      root.updateHints(modifiers, monitor)
      return "ok"
    }

    function hide(): string {
      root.hideHints()
      return "ok"
    }

    function reload(): string {
      root.reloadAndHide()
      return "ok"
    }

    function expand(): string {
      root.expandBindings()
      return root.expanded ? "ok" : "unchanged"
    }

    function pointerState(): string {
      return root.moreHovered ? "over-more" : "outside"
    }

    function state(): string {
      return root.opened ? root.currentModifierKey : "closed"
    }
  }

  Component.onCompleted: reloadBindings()

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      readonly property bool isTarget: String(modelData.name || "") === root.targetMonitor
      readonly property int columns: root.columnCount(root.visibleBindings.length)
      readonly property real desiredWidth: columns * Style.space(218)
        + Math.max(0, columns - 1) * Style.spacing.xxl
        + Style.spacing.panelPadding * 2

      screen: modelData
      visible: isTarget && (root.opened || card.opacity > 0.01)
      anchors { top: true; right: true; bottom: true; left: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      // Keep one visible, non-empty control region for the entire time the
      // overlay is open. This Quickshell version does not reliably reactivate
      // a full-screen layer's mask after the region becomes empty.
      mask: Region { item: moreHitTarget }

      WlrLayershell.namespace: "next-key"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      BorderSurface {
        id: card

        width: Math.min(panel.width * 0.40, Math.max(Style.space(300), panel.desiredWidth))
        height: hintContent.implicitHeight + Style.spacing.panelPadding * 2 + borderTop + borderBottom
        anchors.right: parent.right
        anchors.rightMargin: Style.space(12)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.opened ? Style.space(12) : Style.space(4)
        color: Color.popups.background
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
        radius: Style.cornerRadius
        opacity: root.opened ? 1 : 0

        Behavior on opacity {
          NumberAnimation {
            duration: root.opened ? 100 : 80
            easing.type: Easing.OutCubic
          }
        }

        Behavior on anchors.bottomMargin {
          NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
          id: hintContent
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.left: parent.left
          anchors.margins: Style.spacing.panelPadding
          spacing: Style.spacing.panelGap
          opacity: root.contentOpacity

          Behavior on opacity {
            NumberAnimation { duration: 70; easing.type: Easing.OutCubic }
          }

          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Style.spacing.md

            Repeater {
              model: root.currentModifiers
              ModifierChip { required property string modelData; modifierText: modelData }
            }
          }

          GridLayout {
            id: bindingGrid
            Layout.fillWidth: true
            columns: panel.columns
            columnSpacing: Style.spacing.xxl
            rowSpacing: Style.spacing.md

            Repeater {
              model: root.visibleBindings
              BindingItem {
                required property var modelData
                binding: modelData
                Layout.fillWidth: true
                Layout.preferredWidth: (bindingGrid.width - bindingGrid.columnSpacing * (panel.columns - 1)) / panel.columns
              }
            }
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.currentBindings.length === 0
            text: "No described shortcuts for this modifier set"
            color: Util.alpha(Color.popups.text, 0.68)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Rectangle {
            id: moreButton

            readonly property bool available: root.opened
            readonly property bool actionable: root.overflowBindingCount > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: available ? Style.space(104) : 0
            Layout.preferredHeight: available ? Style.space(24) : 0
            implicitWidth: Layout.preferredWidth
            implicitHeight: Layout.preferredHeight
            visible: available
            radius: Math.min(Style.cornerRadius, Style.space(5))
            color: actionable && root.moreHovered
              ? Util.alpha(Color.accent, 0.18)
              : Util.alpha(Color.popups.text, 0.08)
            border.width: Math.max(1, Style.spacing.hairline)
            border.color: actionable && root.moreHovered
              ? Util.alpha(Color.accent, 0.8)
              : Util.alpha(Color.popups.border, 0.7)

            Text {
              id: moreText
              anchors.centerIn: parent
              text: root.expanded
                ? "− show less"
                : (root.overflowBindingCount > 0
                  ? "+ " + root.overflowBindingCount + " more"
                  : "All shown")
              color: moreButton.actionable && root.moreHovered
                ? Color.accent
                : Util.alpha(Color.popups.text, moreButton.actionable ? 0.72 : 0.5)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }

          }

          RowLayout {
            id: branchRow

            Layout.alignment: Qt.AlignHCenter
            spacing: Style.spacing.lg
            visible: root.modifierBranches.length > 0

            Repeater {
              model: root.modifierBranches
              ModifierChip {
                required property var modelData
                modifierText: String(modelData.modifier)
                count: Number(modelData.count)
                branch: true
              }
            }
          }
        }

        // Keep input geometry outside the dynamic ColumnLayout. Its bottom
        // position matches the visual control but does not move while the grid
        // expands upward or switches modifier groups.
        Item {
          id: moreHitTarget

          width: root.opened ? Style.space(104) : 0
          height: root.opened ? Style.space(24) : 0
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.spacing.panelPadding + card.borderBottom
            + (branchRow.visible ? branchRow.height + hintContent.spacing : 0)
          z: 10

          MouseArea {
            id: moreHitMouse
            anchors.fill: parent
            enabled: root.overflowBindingCount > 0
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onContainsMouseChanged: {
              if (panel.isTarget) root.moreHovered = containsMouse
            }
            onEnabledChanged: {
              if (!enabled && panel.isTarget) root.moreHovered = false
            }
            onClicked: root.toggleExpandedBindings()
          }
        }
      }
    }
  }
}
