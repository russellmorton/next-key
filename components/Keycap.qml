import QtQuick
import qs.Commons

Rectangle {
  id: root

  required property string label

  implicitWidth: Math.max(Style.space(30), keyText.implicitWidth + Style.spacing.lg * 2)
  implicitHeight: Style.space(24)
  radius: Math.min(Style.cornerRadius, Style.space(5))
  color: Util.alpha(Color.popups.text, 0.08)
  border.width: Math.max(1, Style.spacing.hairline)
  border.color: Util.alpha(Color.popups.border, 0.7)

  Text {
    id: keyText
    anchors.centerIn: parent
    text: root.label
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
  }
}
