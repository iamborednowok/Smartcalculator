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
            if (root.currentTab === 5)
                aiLoader.item?.handleResponse(content, isError)
        }
    }

    // ── Theme ──────────────────────────────────────────────────────────
    property bool darkMode: true

    // Expose to child tabs
    property color bgColor:      "#010208"
    property color bg2Color:     "#04041a"
    property color surfaceColor: Qt.rgba(1, 1, 1, 0.042)
    property color textColor:    "#f0f0ff"
    property color text2Color:   "#8888cc"
    property color text3Color:   "#44446a"
    property color borderColor:  Qt.rgba(1, 1, 1, 0.09)
    property color accentColor:  "#7C3AED"
    property color accent2Color: "#A78BFA"
    property var   appSettings:  settings   // ← correct name (was `settings` only, causing AITab bug)

    // ── Active tab ─────────────────────────────────────────────────────
    // CRASH FIX: Loader `active` bindings must NOT reference `tabBar` because
    // tabBar (AppTabBar) is declared BELOW the Loaders in the ColumnLayout.
    // During QML component creation objects are instantiated top-to-bottom, so
    // when the Loader bindings are first evaluated `tabBar` is still null.
    // `null.currentIndex === 0` fails silently → ALL Loaders stay inactive →
    // the screen stays permanently white/blank.
    // Solution: hoist the selected index into a root property that both the
    // Loaders and AppTabBar bind to.  No forward reference; no null access.
    property int currentTab: 0

    // ── History ────────────────────────────────────────────────────────
    property var calcHistory: []
    function addHistory(expr, result) {
        var now = Qt.formatTime(new Date(), "hh:mm")
        var arr = [{ expr: expr, result: result, time: now }]
        for (var i = 0; i < Math.min(calcHistory.length, 49); i++)
            arr.push(calcHistory[i])
        calcHistory = arr
    }

    function showToast(msg, suc) { toast.show(msg, suc) }

    // ── Background — Neon Noir deep space ─────────────────────────────
    background: Item {
        Rectangle { anchors.fill: parent; color: "#010208" }

        // Violet halo — top left
        Rectangle {
            x: -100; y: -140; width: 420; height: 420; radius: 210
            color: "transparent"
            Repeater {
                model: 10
                delegate: Rectangle {
                    anchors.centerIn: parent
                    width:  420 - index * 38; height: 420 - index * 38
                    radius: (420 - index * 38) / 2
                    color: Qt.rgba(0.49, 0.23, 0.93, 0.018 - index * 0.0015)
                }
            }
        }

        // Cyan halo — bottom right
        Rectangle {
            x: root.width - 80; y: root.height - 200
            width: 340; height: 340; radius: 170
            color: "transparent"
            Repeater {
                model: 10
                delegate: Rectangle {
                    anchors.centerIn: parent
                    width:  340 - index * 30; height: 340 - index * 30
                    radius: (340 - index * 30) / 2
                    color: Qt.rgba(0.02, 0.71, 0.83, 0.016 - index * 0.001)
                }
            }
        }

        // Horizontal scanline grid
        Repeater {
            model: 16
            delegate: Rectangle {
                y: index * (root.height / 16)
                width: root.width; height: 1
                color: Qt.rgba(1, 1, 1, 0.009)
            }
        }

        // Diagonal accent stripe (top-right corner)
        Rectangle {
            x: root.width - 60; y: -10
            width: 2; height: 120
            rotation: 30
            color: Qt.rgba(0.49, 0.23, 0.93, 0.18)
        }
        Rectangle {
            x: root.width - 40; y: -10
            width: 1; height: 80
            rotation: 30
            color: Qt.rgba(0.02, 0.71, 0.83, 0.12)
        }
    }

    // ── Layout ─────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true

            // CRASH FIX: all Loaders now bind to root.currentTab (a plain property
            // declared above) rather than tabBar.currentIndex.  tabBar is created
            // AFTER these Loaders in the layout, so tabBar would be null on the
            // first evaluation, causing every Loader to stay inactive (white screen).
            Loader { id: calcLoader;    anchors.fill: parent; active: root.currentTab === 0; visible: active; source: "CalcTab.qml" }
            Loader { id: formulaLoader; anchors.fill: parent; active: root.currentTab === 1; visible: active; source: "FormulaTab.qml" }
            Loader { id: convertLoader; anchors.fill: parent; active: root.currentTab === 2; visible: active; source: "ConvertTab.qml" }
            Loader { id: randomLoader;  anchors.fill: parent; active: root.currentTab === 3; visible: active; source: "RandomTab.qml" }
            Loader { id: graphLoader;   anchors.fill: parent; active: root.currentTab === 4; visible: active; source: "GraphTab.qml" }
            Loader { id: aiLoader;      anchors.fill: parent; active: true; visible: root.currentTab === 5; source: "AITab.qml" }
        }

        AppTabBar {
            id: tabBar
            Layout.fillWidth: true
            currentIndex: root.currentTab
            onTabClicked: function(i) { root.currentTab = i }
        }
    }

    ToastMessage { id: toast; anchors.fill: parent }
    Component.onCompleted: root.darkMode = true
}
