import QtQuick
import QtQuick.Layouts
import qs.Commons

Item {
  id: root

  required property var binding

  implicitHeight: Style.space(30)
  implicitWidth: Style.space(210)

  RowLayout {
    anchors.fill: parent
    spacing: Style.spacing.lg

    Keycap {
      label: String(root.binding.displayKey || root.binding.key || "")
      Layout.alignment: Qt.AlignVCenter
    }

    Text {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text: String(root.binding.description || "")
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      maximumLineCount: 1
    }
  }
}
