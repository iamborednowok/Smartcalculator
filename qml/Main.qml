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

    AppSettings { id: settings }
    MathEngine  { id: mathEngine }
    ApiClient   { id: apiClient
        onResponseReceived: function(content, isError) {
            if (root.currentTab === 6)
                aiLoader.item?.handleResponse(content, isError)
        }
    }

    // FIX: start in light mode by default (matches user preference)
    property bool darkMode: false
    property var  appSettings: settings
    property int  currentTab:  0
    property int  prevTab:     0
    property var  calcHistory: []

    // ── Responsive geometry ──────────────────────────────────────────
    readonly property bool isWide:      root.width >= 600
    readonly property bool isLandscape: root.height < root.width
    readonly property int  contentMaxW: Math.min(root.width, isWide ? 540 : root.width)

    readonly property bool isMoreActive: currentTab === 1 || currentTab === 3 || currentTab === 5
    readonly property int  headerH: Math.round(56 * Theme.scale)

    onDarkModeChanged: {
        Theme.dark        = darkMode
        settings.darkMode = darkMode
    }

    Component.onCompleted: {
        root.darkMode = settings.darkMode
        Theme.dark    = root.darkMode
        recalcScale()
    }
    onWidthChanged:  Qt.callLater(recalcScale)
    onHeightChanged: Qt.callLater(recalcScale)

    function recalcScale() {
        var scaleW = root.width  / 400
        var scaleH = root.height / 820
        var raw    = Math.min(scaleW, scaleH)
        var maxS   = root.isWide ? 1.55 : 1.35
        Theme.scale = Math.max(0.72, Math.min(maxS, raw))
    }

    function addHistory(expr, result) {
        var now = Qt.formatTime(new Date(), "hh:mm")
        var arr = [{ expr: expr, result: result, time: now }]
        for (var i = 0; i < Math.min(calcHistory.length, 49); i++)
            arr.push(calcHistory[i])
        calcHistory = arr
    }
    function showToast(msg, suc) { toast.show(msg, suc) }

    // ── Background ───────────────────────────────────────────────────
    background: Item {

        // DARK: deep ocean navy with teal/cyan glows
        Item {
            anchors.fill: parent; visible: root.darkMode

            Rectangle { anchors.fill: parent; color: "#060D14" }

            Canvas {
                id: darkCanvas
                anchors.fill: parent
                Component.onCompleted: requestPaint()
                Connections {
                    target: root
                    function onDarkModeChanged() { if (root.darkMode) darkCanvas.requestPaint() }
                }
                onPaint: {
                    var ctx = getContext("2d")
                    var W = width, H = height

                    var g1 = ctx.createRadialGradient(60, 50, 0, 60, 50, 280)
                    g1.addColorStop(0.00, "rgba(0,200,168,0.18)")
                    g1.addColorStop(0.50, "rgba(0,200,168,0.06)")
                    g1.addColorStop(1.00, "rgba(0,0,0,0)")
                    ctx.fillStyle = g1; ctx.fillRect(0, 0, W, H)

                    var g2 = ctx.createRadialGradient(W + 20, H - 40, 0, W + 20, H - 40, 260)
                    g2.addColorStop(0.00, "rgba(0,140,200,0.16)")
                    g2.addColorStop(0.50, "rgba(0,100,160,0.06)")
                    g2.addColorStop(1.00, "rgba(0,0,0,0)")
                    ctx.fillStyle = g2; ctx.fillRect(0, 0, W, H)

                    var g3 = ctx.createRadialGradient(W * 0.55, H * 0.42, 0, W * 0.55, H * 0.42, 160)
                    g3.addColorStop(0.00, "rgba(0,229,204,0.04)")
                    g3.addColorStop(1.00, "rgba(0,0,0,0)")
                    ctx.fillStyle = g3; ctx.fillRect(0, 0, W, H)
                }
            }
        }

        // LIGHT: clean sky-blue gradient — animated clouds
        Item {
            anchors.fill: parent; visible: !root.darkMode; clip: true

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#E9F5FC" }
                    GradientStop { position: 0.5; color: "#D8EDFA" }
                    GradientStop { position: 1.0; color: "#C8E3F8" }
                }
            }

            // Animated cloud blobs
            Rectangle {
                id: cl1; width: 240; height: 92; radius: 999
                color: Qt.rgba(1, 1, 1, 0.60); y: 18
                NumberAnimation on x {
                    from: -30; to: 50; duration: 9400
                    loops: Animation.Infinite; running: !root.darkMode; easing.type: Easing.InOutSine
                }
            }
            Rectangle {
                width: 290; height: 126; radius: 999
                color: Qt.rgba(1, 1, 1, 0.22)
                y: cl1.y - 18; x: cl1.x - 28
            }
            Rectangle {
                id: cl2; width: 178; height: 66; radius: 999
                color: Qt.rgba(1, 1, 1, 0.50); y: 100
                NumberAnimation on x {
                    from: 160; to: 228; duration: 7800
                    loops: Animation.Infinite; running: !root.darkMode; easing.type: Easing.InOutSine
                }
            }
            Rectangle {
                id: cl3; width: 128; height: 48; radius: 999
                color: Qt.rgba(1, 1, 1, 0.40); y: 178
                NumberAnimation on x {
                    from: 24; to: 100; duration: 11600
                    loops: Animation.Infinite; running: !root.darkMode; easing.type: Easing.InOutSine
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 220
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0.05,0.16,0.32,0.07) }
                }
            }
        }
    }

    // ── Root shell ───────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        // Frosted side rails (tablets only)
        Rectangle {
            visible: root.isWide
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            width: (parent.width - root.contentMaxW) / 2
            color: root.darkMode ? Qt.rgba(0,0,0,0.20) : Qt.rgba(1,1,1,0.20)
            Behavior on color { ColorAnimation { duration: Theme.normal } }
        }
        Rectangle {
            visible: root.isWide
            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            width: (parent.width - root.contentMaxW) / 2
            color: root.darkMode ? Qt.rgba(0,0,0,0.20) : Qt.rgba(1,1,1,0.20)
            Behavior on color { ColorAnimation { duration: Theme.normal } }
        }

        // ── Content column ────────────────────────────────────────────
        Item {
            id: contentCol
            anchors { top: parent.top; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            width: root.contentMaxW

            ColumnLayout {
                anchors.fill: parent; spacing: 0

                // ── Top Header ────────────────────────────────────────
                Rectangle {
                    id: appHeader
                    Layout.fillWidth: true
                    height: root.headerH

                    // FIX: solid header background, no transparency bleed
                    color: Theme.tabBg
                    Behavior on color { ColorAnimation { duration: Theme.normal } }

                    // Drop shadow for header bottom edge
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.00; color: "transparent" }
                            GradientStop { position: 0.15; color: Theme.tabSep0 }
                            GradientStop { position: 0.50; color: Theme.tabSep0 }
                            GradientStop { position: 0.85; color: Theme.tabSep1 }
                            GradientStop { position: 1.00; color: "transparent" }
                        }
                    }

                    // Left: Logo + App name
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Math.round(16 * Theme.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(9 * Theme.scale)

                        Rectangle {
                            width:  Math.round(30 * Theme.scale)
                            height: Math.round(30 * Theme.scale)
                            radius: Math.round(9  * Theme.scale)
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Theme.accent }
                                GradientStop { position: 1.0; color: Theme.cyan  }
                            }
                            Text {
                                anchors.centerIn: parent; text: "⊞"
                                font.pixelSize: Math.round(15 * Theme.scale)
                                color: "#FFFFFF"; font.family: Theme.fontSans
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            Text {
                                text: "Smart"
                                font.pixelSize: Math.round(15 * Theme.scale)
                                font.weight: Font.Bold; font.family: Theme.fontSans
                                color: Theme.text
                                Behavior on color { ColorAnimation { duration: Theme.normal } }
                            }
                            // Thin accent line under brand name
                            Rectangle {
                                width: parent.children[0].implicitWidth
                                height: Math.round(2 * Theme.scale); radius: 1
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: Theme.accent }
                                    GradientStop { position: 1.0; color: Theme.cyan   }
                                }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Calc"
                            font.pixelSize: Math.round(15 * Theme.scale)
                            font.weight: Font.Bold; font.family: Theme.fontSans
                            color: Theme.accent
                            Behavior on color { ColorAnimation { duration: Theme.normal } }
                        }
                    }

                    // Right: dark-mode toggle only (More moved to tab bar)
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(12 * Theme.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(4 * Theme.scale)

                        // Dark / Light mode toggle
                        Rectangle {
                            width:  Math.round(38 * Theme.scale)
                            height: Math.round(38 * Theme.scale)
                            radius: Math.round(11 * Theme.scale)
                            color:  dmMa.pressed
                                ? Theme.accentDim
                                : (Theme.dark ? Qt.rgba(1,1,1,0.06) : Qt.rgba(0.07,0.33,0.75,0.08))
                            Behavior on color { ColorAnimation { duration: 120 } }
                            border.color: Theme.dark ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0.07,0.33,0.75,0.25)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: root.darkMode ? "☀" : "☽"
                                font.pixelSize: Math.round(17 * Theme.scale)
                                color: Theme.text2
                                Behavior on color { ColorAnimation { duration: Theme.normal } }
                            }
                            MouseArea { id: dmMa; anchors.fill: parent; onClicked: root.darkMode = !root.darkMode }
                        }
                    }
                }

                // ── Tab content ───────────────────────────────────────
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true

                    Loader { id: calcLoader;    anchors.fill: parent; source: "CalcTab.qml"
                        active: true
                        opacity: root.currentTab === 0 ? 1 : 0; visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }

                    Loader { id: formulaLoader; anchors.fill: parent; source: "FormulaTab.qml"
                        active: root.currentTab === 1 || formulaLoader.status === Loader.Ready
                        opacity: root.currentTab === 1 ? 1 : 0; visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }

                    Loader { id: convertLoader; anchors.fill: parent; source: "ConvertTab.qml"
                        active: root.currentTab === 2 || convertLoader.status === Loader.Ready
                        opacity: root.currentTab === 2 ? 1 : 0; visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }

                    Loader { id: randomLoader;  anchors.fill: parent; source: "RandomTab.qml"
                        active: root.currentTab === 3 || randomLoader.status === Loader.Ready
                        opacity: root.currentTab === 3 ? 1 : 0; visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }

                    Loader { id: graphLoader;   anchors.fill: parent; source: "GraphTab.qml"
                        active: root.currentTab === 4 || graphLoader.status === Loader.Ready
                        opacity: root.currentTab === 4 ? 1 : 0; visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }

                    Loader { id: progLoader;    anchors.fill: parent; source: "ProgrammerTab.qml"
                        active: root.currentTab === 5 || progLoader.status === Loader.Ready
                        opacity: root.currentTab === 5 ? 1 : 0; visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }

                    Loader { id: aiLoader;      anchors.fill: parent; source: "AITab.qml"
                        active: root.currentTab === 6 || aiLoader.status === Loader.Ready
                        opacity: root.currentTab === 6 ? 1 : 0; visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }
                }

                // ── Bottom tab bar ─────────────────────────────────────
                AppTabBar {
                    id: tabBar
                    Layout.fillWidth: true
                    currentIndex: root.currentTab
                    // FIX: tab bar z is above MoreSheet dim overlay
                    z: 60
                    onTabClicked: function(i) {
                        if (i === -1) {
                            // "More" button — toggle the sheet
                            moreSheet.toggle()
                        } else {
                            moreSheet.close()
                            root.currentTab = i
                        }
                    }
                }
            }

            // ── MoreSheet overlay (above content, below tab bar) ───────
            MoreSheet {
                id: moreSheet
                // Fill only up to (but not including) the tab bar
                anchors {
                    top:    parent.top
                    left:   parent.left
                    right:  parent.right
                    bottom: tabBar.top
                }
                topOffset:    root.headerH
                currentIndex: root.currentTab
                onTabClicked: function(i) { root.currentTab = i }
            }
        }
    }

    ToastMessage { id: toast; anchors.fill: parent; z: 200 }
}
