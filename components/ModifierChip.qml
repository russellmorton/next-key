import QtQuick
import QtQuick.Layouts
import qs.Commons

Rectangle {
  id: root

  required property string modifierText
  property int count: -1
  property bool branch: false

  implicitWidth: chipRow.implicitWidth + Style.spacing.lg * 2
  implicitHeight: Style.space(24)
  radius: Math.min(Style.cornerRadius, Style.space(5))
  color: root.branch ? Util.alpha(Color.accent, 0.12) : Util.alpha(Color.popups.text, 0.08)
  border.width: Math.max(1, Style.spacing.hairline)
  border.color: root.branch ? Util.alpha(Color.accent, 0.72) : Util.alpha(Color.popups.border, 0.7)

  RowLayout {
    id: chipRow
    anchors.centerIn: parent
    spacing: Style.spacing.sm

    Text {
      text: root.branch ? "+" : ""
      visible: root.branch
      color: Color.accent
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Text {
      text: root.modifierText
      color: root.branch ? Color.accent : Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Text {
      text: String(root.count)
      visible: root.count >= 0
      color: Util.alpha(Color.popups.text, 0.72)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }
}
