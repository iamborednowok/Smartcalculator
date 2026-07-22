import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import SmartCalc.Backend 1.0
import "components"

ApplicationWindow {
    id: root
    visible: true
    width:  400
    height: 820
    title:  "SmartCalc"

    // ── Shared backend instances ─────────────────────────────────────
    // Single instance each, reached by every tab via QML's id scope-chain
    // (every tab below is instantiated as a direct child of this window).
    // Do NOT duplicate these inside individual tabs.
    AppSettings { id: settings }
    MathEngine  { id: mathEngine }
    ApiClient   { id: apiClient
        onResponseReceived: function(content, isError) {
            // BUG FIX: this used to gate on `root.currentTab === 6`, so
            // asking the AI something and switching tabs before the reply
            // arrived silently dropped it — AITab's `loading` flag never
            // cleared, wedging its Send button (disabled while loading)
            // for the rest of the session. AITab is lazy-loaded (see
            // aiLoader below) so a response can only ever exist after the
            // user has visited it at least once, meaning aiLoader.item is
            // always valid here — deliver it regardless of which tab is
            // on screen; AITab shows a toast itself if the user has since
            // navigated away (see AITab.qml's handleResponse).
            if (aiLoader.item) aiLoader.item.handleResponse(content, isError)
        }
    }

    property bool darkMode:    false
    property int  currentTab:  0
    property var  calcHistory: []

    // Orientation, not size — the "wide vs phone" breakpoint used to be
    // width >= 600, but that's a *size* threshold (right for responsive
    // web, wrong for a device that rotates): a tablet held in portrait is
    // still narrower than it is tall and should get the portrait layout,
    // and a phone rotated to landscape should get the landscape one the
    // instant it's rotated, at any absolute size. Comparing width to
    // height captures "which way is the device held" directly.
    readonly property bool isWide: width > height

    // ── Single source of truth for all navigation.
    // To add, rename, or reorder a tab:
    //   - edit this array only
    //   - add the corresponding tab content in the StackLayout below
    //   - TabPillBar reads from here automatically; each tab's pill color
    //     comes from Theme.tabColors[index], not from this array.
    //
    // Fields:
    //   icon    — emoji/symbol shown in nav
    //   label   — display name
    //   index   — must match StackLayout child order (0-based)
    readonly property var allTabs: [
        { icon: "▦",   label: "Calc",        index: 0 },
        { icon: "∑",   label: "Formula",     index: 1 },
        { icon: "⇄",   label: "Convert",     index: 2 },
        { icon: "⚂",   label: "Random",      index: 3 },
        { icon: "∿",   label: "Graph",       index: 4 },
        { icon: "{}",  label: "Programmer",  index: 5 },
        { icon: "✦",   label: "AI",          index: 6 },
    ]

    onDarkModeChanged: { Theme.dark = darkMode; settings.darkMode = darkMode }

    Component.onCompleted: {
        darkMode   = settings.darkMode
        Theme.dark = darkMode
        recalcScale()
    }
    onWidthChanged:  Qt.callLater(recalcScale)
    onHeightChanged: Qt.callLater(recalcScale)

    function recalcScale() {
        var s = Math.min(width / 400, height / 820)
        Theme.scale = Math.max(0.78, Math.min(isWide ? 1.5 : 1.25, s))
    }

    function addHistory(expr, result) {
        var now = Qt.formatTime(new Date(), "hh:mm")
        // Cap at 50 entries total (1 new + up to 49 kept).
        calcHistory = [{ expr: expr, result: result, time: now }].concat(calcHistory.slice(0, 49))
    }
    function showToast(msg, ok) { toast.show(msg, ok) }

    background: Rectangle {
        color: Theme.bg
        Behavior on color { ColorAnimation { duration: Theme.normal } }
        AmbientGlow { }
    }

    // ── Root shell ──────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        // Centered content column (caps at contentMaxW on wide screens)
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width: root.isWide ? Math.min(root.width, 760) : root.width

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ── One nav, every orientation ──────────────────────
                // Used to be TopRibbon (wide) vs AppTabBar+MoreSheet
                // (narrow) chosen by a width breakpoint. Now a single
                // always-top, always-scrollable pill row — rotating the
                // device changes the *content* layout below (see e.g.
                // ProgrammerTab's landscape 3-column view), not which
                // nav component exists.
                TabPillBar {
                    Layout.fillWidth: true
                    model:    root.allTabs
                    currentIndex: root.currentTab
                    darkMode: root.darkMode
                    onTabClicked:   function(i) { root.currentTab = i }
                    onThemeToggled: root.darkMode = !root.darkMode
                }

                // ── Tab content (reflows per-tab based on root.isWide) ──
                // PERF FIX: all 7 tabs used to be direct StackLayout
                // children, which meant all 7 full object graphs — every
                // Repeater, every delegate, every Component.onCompleted
                // (GraphTab painted a full canvas nobody was looking at;
                // AITab stood up a FileDialog and a Settings store) — were
                // built synchronously at app launch, even though only one
                // tab is ever visible at a time. Every tab but the startup
                // one (Calc) now lives behind a Loader that only activates
                // the first time its tab is actually opened.
                //
                // `active: root.currentTab === N || item !== null` is a
                // "load once, keep forever" latch: false until tab N is
                // first opened, then permanently true afterwards (reading
                // `item` inside its own active binding is intentional and
                // safe — see REBUILD_NOTES.md). That "keep forever" part
                // matters as much as the lazy part: these tabs hold live,
                // uniquely-generated state (quiz score, graph functions,
                // AI chat history, the programmer tab's current value)
                // that would be silently lost if the Loader tore its item
                // down every time you switched away.
                //
                // Each tab's isCurrentTab is now a plain property driven
                // from root.currentTab instead of StackLayout.isCurrentItem
                // — a Loader's loaded item is a grandchild of StackLayout,
                // not a direct child, and StackLayout only ever sets that
                // attached property on its own direct children, so the
                // attached-property form would silently never fire once a
                // tab was behind a Loader.
                StackLayout {
                    id: stack
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    currentIndex: root.currentTab

                    // Index order must match allTabs[n].index values above.
                    CalcTab { isCurrentTab: root.currentTab === 0 }   // 0 — startup tab, loaded eagerly

                    Loader {
                        id: formulaLoader
                        Layout.fillWidth: true; Layout.fillHeight: true
                        active: root.currentTab === 1 || item !== null
                        sourceComponent: FormulaTab { isCurrentTab: root.currentTab === 1 }
                    }
                    Loader {
                        id: convertLoader
                        Layout.fillWidth: true; Layout.fillHeight: true
                        active: root.currentTab === 2 || item !== null
                        sourceComponent: ConvertTab { isCurrentTab: root.currentTab === 2 }
                    }
                    Loader {
                        id: randomLoader
                        Layout.fillWidth: true; Layout.fillHeight: true
                        active: root.currentTab === 3 || item !== null
                        sourceComponent: RandomTab { isCurrentTab: root.currentTab === 3 }
                    }
                    Loader {
                        id: graphLoader
                        Layout.fillWidth: true; Layout.fillHeight: true
                        active: root.currentTab === 4 || item !== null
                        sourceComponent: GraphTab { isCurrentTab: root.currentTab === 4 }
                    }
                    Loader {
                        id: programmerLoader
                        Layout.fillWidth: true; Layout.fillHeight: true
                        active: root.currentTab === 5 || item !== null
                        sourceComponent: ProgrammerTab { isCurrentTab: root.currentTab === 5 }
                    }
                    Loader {
                        id: aiLoader   // 6 — apiClient (above) routes responses here
                        Layout.fillWidth: true; Layout.fillHeight: true
                        active: root.currentTab === 6 || item !== null
                        sourceComponent: AITab { isCurrentTab: root.currentTab === 6 }
                    }
                }
            }
        }

        ToastMessage { id: toast; anchors.fill: parent; z: 200 }
    }
}
