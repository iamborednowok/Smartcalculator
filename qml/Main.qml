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

    property bool darkMode: false
    property var  appSettings: settings
    property int  currentTab: 0
    property int  prevTab:    0
    property var  calcHistory: []

    onDarkModeChanged: {
        Theme.dark        = darkMode
        settings.darkMode = darkMode
    }

    Component.onCompleted: {
        root.darkMode = settings.darkMode
        Theme.dark    = root.darkMode
        var baseW  = 400
        var baseH  = 820
        var scaleW = root.width  / baseW
        var scaleH = root.height / baseH
        Theme.scale = Math.max(0.75, Math.min(1.35, Math.min(scaleW, scaleH)))
    }

    onWidthChanged:  Qt.callLater(function() {
        Theme.scale = Math.max(0.75, Math.min(1.35, Math.min(root.width / 400, root.height / 820)))
    })
    onHeightChanged: Qt.callLater(function() {
        Theme.scale = Math.max(0.75, Math.min(1.35, Math.min(root.width / 400, root.height / 820)))
    })

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

            Rectangle {
                x: root.width - 56; y: -10; width: 1; height: 110; rotation: 28
                color: Qt.rgba(0, 0.78, 0.66, 0.18)
            }
            Rectangle {
                x: root.width - 36; y: -10; width: 1; height: 72; rotation: 28
                color: Qt.rgba(0, 0.90, 0.80, 0.10)
            }
            Rectangle {
                x: 14; y: root.height - 90; width: 1; height: 100; rotation: -28
                color: Qt.rgba(0, 0.78, 0.66, 0.12)
            }
        }

        Item {
            anchors.fill: parent; visible: !root.darkMode; clip: true

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#E9F5FC" }
                    GradientStop { position: 0.5; color: "#D2E9F9" }
                    GradientStop { position: 1.0; color: "#BDDAF3" }
                }
            }

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
                id: cl4; width: 96; height: 36; radius: 999
                color: Qt.rgba(1, 1, 1, 0.30); y: 60
                NumberAnimation on x {
                    from: root.width - 60; to: root.width - 130; duration: 13200
                    loops: Animation.Infinite; running: !root.darkMode; easing.type: Easing.InOutSine
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 220
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0.05,0.16,0.32,0.08) }
                }
            }
            Rectangle {
                width: parent.width; height: 64
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1,1,1,0.26) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    // ── Layout ───────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent; spacing: 0

        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            // Tab 0 (CALC) loads immediately — it's the default view.
            // All others lazy-load on first visit so startup is instant.
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

        AppTabBar {
            id: tabBar
            Layout.fillWidth: true
            currentIndex: root.currentTab
            onTabClicked: function(i) {
                moreSheet.close()
                root.currentTab = i
            }
            onMoreClicked: moreSheet.toggle()
        }
    }

    // ── More sheet overlay (above everything) ─────────────────────────
    MoreSheet {
        id: moreSheet
        anchors.fill: parent
        currentIndex:  root.currentTab
        onTabClicked:  function(i) { root.currentTab = i }
    }

    ToastMessage { id: toast; anchors.fill: parent }
}
