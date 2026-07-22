import QtQuick
import QtQuick.Layouts

// ── Shared shell for AI-skill inline results ────────────────────────────
// Small "the app verified this" card shown under an assistant reply when
// a skill actually computed something — see AITab.qml's extractEvalResult/
// extractConvertResult/extractRollResult/extractBaseResult, which run the
// model's proposed params through mathEngine (or plain JS for dice/coin/
// range) rather than trusting whatever number the model put in "answer".
// Same trust boundary plot_graph established first; this is the text-card
// counterpart to MiniGraphPlot for skills that produce a value, not a curve.
//
// Two content shapes, switched on whether `rows` is set:
//   - title/value : one context line + one emphasized result
//                   (evaluate_expression, convert_units, roll_random)
//   - rows        : a small label/value table, e.g. DEC/HEX/OCT/BIN
//                   (convert_base)
//
// accentColor is deliberately just Theme.tabColors[N] for whichever tab
// "owns" that domain (Calc/Convert/Random/Programmer) — same reasoning
// Theme.qml's own tabColors comment gives for reusing established hues
// rather than inventing a second palette. See call sites in AITab.qml.
//
// Sizing mirrors AITab.qml's own chat-bubble Rectangle exactly: explicit
// x/y/width on the inner layout so wrapped Text can compute a real
// implicitHeight, then childrenRect.height rolls that up to the card, and
// implicitHeight rolls that up to this component for whatever Layout it
// sits in (AITab.qml uses Layout.fillWidth with no fixed height, same as
// every other conditional element in that bubble).
Item {
    id: root
    property color  accentColor: Theme.accent
    property string icon:        "✓"
    property string title:       ""
    property string value:       ""
    property var    rows:        []   // [{label, value}, ...] — overrides title/value when non-empty

    implicitHeight: card.height

    Rectangle {
        id: card
        width: root.width
        height: childrenRect.height + Theme.sp3 * 2
        radius: Theme.rMd
        color: Theme.surface

        Rectangle {
            id: accentBar
            width: 3
            radius: 1.5
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.sp2
            color: root.accentColor
        }

        RowLayout {
            x: accentBar.width + Theme.sp2 * 2
            y: Theme.sp3
            width: card.width - x - Theme.sp3
            spacing: Theme.sp2

            Text {
                text: root.icon
                font.pixelSize: Math.round(15 * Theme.scale)
                Layout.alignment: Qt.AlignTop
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                // ── title/value mode ────────────────────────────────
                Text {
                    Layout.fillWidth: true
                    visible: root.rows.length === 0
                    text: root.title
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Math.round(11 * Theme.scale)
                    wrapMode: Text.WordWrap
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.rows.length === 0
                    text: root.value
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.weight: Font.DemiBold
                    font.pixelSize: Math.round(15 * Theme.scale)
                    wrapMode: Text.WordWrap
                }

                // ── rows/table mode (convert_base's DEC/HEX/OCT/BIN) ──
                Repeater {
                    model: root.rows
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.sp2
                        Text {
                            text: modelData.label
                            color: Theme.textFaint
                            font.family: Theme.fontSans
                            font.weight: Font.Bold
                            font.pixelSize: Math.round(9 * Theme.scale)
                            Layout.preferredWidth: Math.round(28 * Theme.scale)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.value
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Math.round(12 * Theme.scale)
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }
        }
    }
}
