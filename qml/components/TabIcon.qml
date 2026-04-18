import QtQuick

// TabIcon — smart icon loader for AppTabBar.
//
// Load order per tab (filename = label.toLowerCase()):
//   1. qml/icons/<label>.png
//   2. qml/icons/<label>.svg
//   3. qml/icons/<label>.jpg
//   4. fallbackIcon emoji/text (always works)
//
// To add a custom icon just drop the file in qml/icons/ with the right
// name, add it to RESOURCES in CMakeLists.txt, and rebuild.

Item {
    id: root
    width:  18
    height: 18

    // ── public API ───────────────────────────────────────────────────
    property string label:        ""      // tab label, e.g. "CALC"
    property string fallbackIcon: ""      // emoji / text when no image found
    property bool   isActive:     false
    property bool   isMono:       false   // true for "01" (PROG tab)

    // ── internals ────────────────────────────────────────────────────
    readonly property var   _fmts:    ["png", "svg", "jpg"]
    property      int       _fi:      0
    property      bool      _useText: false

    // Reset the probe chain whenever the label changes
    onLabelChanged: { _fi = 0; _useText = false }

    // ── custom image ─────────────────────────────────────────────────
    Image {
        id: img
        anchors.fill: parent
        visible:     !root._useText && status === Image.Ready
        fillMode:     Image.PreserveAspectFit
        smooth:       true
        mipmap:       true

        // "../icons/" navigates from qml/components/ up to qml/icons/
        source: root._useText
                ? ""
                : ("../icons/" + root.label.toLowerCase()
                   + "." + root._fmts[root._fi])

        onStatusChanged: {
            if (status === Image.Error) {
                if (root._fi < root._fmts.length - 1)
                    root._fi++          // try next format
                else
                    root._useText = true // all formats exhausted → emoji
            }
        }
    }

    // ── emoji / text fallback ────────────────────────────────────────
    Text {
        id: fallbackText
        anchors.centerIn: parent
        visible:  root._useText || img.status !== Image.Ready

        text:           root.fallbackIcon
        font.pixelSize: root.isMono ? 12 : 14
        font.family:    root.isMono ? Theme.fontMono : ""
        font.weight:    root.isMono ? Font.Bold : Font.Normal
        color:  root.isActive ? Theme.tabActive : Theme.tabInactive

        Behavior on color { ColorAnimation { duration: 150 } }
    }
}
