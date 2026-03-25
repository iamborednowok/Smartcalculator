import QtQuick
import QtQuick.Layouts
import "components"

Item {
    id: root
    property var window: ApplicationWindow.window

    // ── State ─────────────────────────────────────────────────────────
    property int    diceType:    6
    property int    diceCount:   1
    property var    diceResults: []
    property var    diceHistory: []

    property var    coinResult:  null   // null | "H" | "T"
    property bool   coinFlipping: false
    property var    coinHistory: []

    property string randMin: "1"
    property string randMax: "100"
    property var    randResult:  null
    property var    randHistory: []

    // Math quiz
    property var    currentProb:  null
    property string mathAnswer:   ""
    property var    mathChecked:  null   // null | true | false
    property var    mathScore:    ({right:0, wrong:0})
    property int    streak:       0
    property string difficulty:   "Easy"

    readonly property var difficulties: ["Easy","Hard","Nightmare","Impossible"]
    readonly property var diceTypes:    [4,6,8,10,12,20,100]

    function newMathProblem() {
        var prob = null
        if (difficulty === "Easy") {
            var ops  = ["+","-","×"]
            var op   = ops[Math.floor(Math.random() * ops.length)]
            var a    = Math.floor(Math.random()*99)+1
            var b    = Math.floor(Math.random()*99)+1
            var q, ans
            if      (op === "+") { q = a+" + "+b;  ans = a+b }
            else if (op === "-") { q = (a+b)+" − "+b; ans = a }
            else                 { q = a+" × "+b;  ans = a*b }
            prob = {q: q, a: ans}
        } else if (difficulty === "Hard") {
            var t = Math.random()
            if (t < 0.3) {
                var a = Math.floor(Math.random()*90)+10, b = Math.floor(Math.random()*25)+5
                prob = {q: a+" × "+b, a: a*b}
            } else if (t < 0.6) {
                var a = Math.floor(Math.random()*9)+2, b = Math.floor(Math.random()*8)+2
                var c = Math.floor(Math.random()*6)+2, d = Math.floor(Math.random()*5)+1
                prob = {q: a+" × "+b+" + "+c+" × "+d, a: a*b+c*d}
            } else {
                var m = Math.floor(Math.random()*8)+2, x = Math.floor(Math.random()*20)+1
                var cc = Math.floor(Math.random()*20)
                prob = {q: m+"x + "+cc+" = "+(m*x+cc)+"  →  x = ?", a: x}
            }
        } else if (difficulty === "Nightmare") {
            var ops2 = ["+","-","×"]
            var op2  = ops2[Math.floor(Math.random()*ops2.length)]
            var b2   = Math.floor(Math.random()*9)+2
            var d2   = Math.floor(Math.random()*9)+2
            var a2   = Math.floor(Math.random()*b2-1)+1
            var c2   = Math.floor(Math.random()*d2-1)+1
            var num  = a2*d2+b2*c2, den = b2*d2
            prob = {q: a2+"/"+b2+" + "+c2+"/"+d2, a: parseFloat((num/den).toFixed(4))}
        } else {
            var bases  = [2,3,5,7,10]
            var b3     = bases[Math.floor(Math.random()*bases.length)]
            var exp3   = Math.floor(Math.random()*6)+2
            prob = {q: "log₍"+b3+"₎("+Math.pow(b3,exp3)+")", a: exp3}
        }
        currentProb  = prob
        mathAnswer   = ""
        mathChecked  = null
    }

    function checkAnswer() {
        if (!currentProb || mathAnswer.trim() === "") return
        var user = parseFloat(mathAnswer)
        var correct = Math.abs(user - currentProb.a) < 0.01
        mathChecked = correct
        if (correct) {
            mathScore = {right: mathScore.right+1, wrong: mathScore.wrong}
            streak++
            if (window) window.showToast("✓ Correct!", true)
        } else {
            mathScore = {right: mathScore.right, wrong: mathScore.wrong+1}
            streak = 0
            if (window) window.showToast("✗ Answer: " + currentProb.a)
        }
    }

    Flickable {
        anchors.fill: parent; anchors.margins: 14
        contentHeight: rdCol.implicitHeight + 20
        clip: true

        ColumnLayout {
            id: rdCol
            width: parent.width
            spacing: 14

            // ── DICE ──────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; radius: 16
                color: Qt.rgba(0,0,0,0.20); border.color: Qt.rgba(1,1,1,0.08); border.width: 1
                height: diceSection.implicitHeight + 24

                ColumnLayout {
                    id: diceSection
                    anchors { left:parent.left; right:parent.right; top:parent.top; margins:14 }
                    spacing: 10

                    RowLayout {
                        Text { text: "🎲 DICE ROLLER"; font.pixelSize: 9; color: "#6060a0"; font.letterSpacing: 1 }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 52; height: 20; radius: 8
                            color: Qt.rgba(0.42,0.36,0.91,0.15)
                            border.color: Qt.rgba(0.42,0.36,0.91,0.35); border.width: 1
                            Text { anchors.centerIn: parent; text: diceCount+"d"+diceType
                                font.pixelSize: 9; color: "#a898ff"; font.family: "JetBrains Mono" }
                        }
                    }

                    // Dice type pills
                    Row { spacing: 6
                        Repeater {
                            model: diceTypes
                            delegate: UnitPill { label: "d"+modelData; active: diceType===modelData
                                onClicked: diceType = modelData }
                        }
                    }

                    // Count pills
                    RowLayout {
                        Text { text: "Count:"; font.pixelSize: 11; color: "#8888b8" }
                        Row { spacing: 5
                            Repeater { model: [1,2,3,4,5,6]
                                delegate: UnitPill { label: ""+modelData; active: diceCount===modelData
                                    onClicked: diceCount = modelData; width: 30 }
                            }
                        }
                    }

                    // Roll button
                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 10
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#5b50f2" }
                            GradientStop { position: 1.0; color: "#7c3aed" }
                        }
                        Text { anchors.centerIn: parent; text: "Roll!"; color: "#fff"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent
                            onClicked: {
                                var rolls = []
                                for (var i = 0; i < diceCount; i++) rolls.push(Math.floor(Math.random()*diceType)+1)
                                diceResults = rolls
                                var sum = rolls.reduce(function(a,b){return a+b},0)
                                diceHistory = [{rolls:rolls, sum:sum}].concat(diceHistory.slice(0,4))
                            }
                        }
                    }

                    // Results
                    Flow {
                        visible: diceResults.length > 0
                        Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: diceResults
                            delegate: Rectangle {
                                width: 44; height: 44; radius: 10
                                color: Qt.rgba(0.42,0.36,0.91,0.20)
                                border.color: Qt.rgba(0.42,0.36,0.91,0.30); border.width: 1
                                Text { anchors.centerIn: parent; text: modelData
                                    color: "#d8d0ff"; font.pixelSize: 18; font.weight: Font.Light }
                            }
                        }
                    }
                    Text {
                        visible: diceResults.length > 1
                        text: "Sum: " + diceResults.reduce(function(a,b){return a+b},0)
                            + "  Min: " + Math.min.apply(null, diceResults)
                            + "  Max: " + Math.max.apply(null, diceResults)
                        font.pixelSize: 11; color: "#8888b8"
                    }
                }
            }

            // ── COIN ──────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; radius: 16
                color: Qt.rgba(0,0,0,0.20); border.color: Qt.rgba(1,1,1,0.08); border.width: 1
                height: coinSection.implicitHeight + 24

                ColumnLayout {
                    id: coinSection
                    anchors { left:parent.left; right:parent.right; top:parent.top; margins:14 }
                    spacing: 10

                    RowLayout {
                        Text { text: "🪙 COIN"; font.pixelSize: 9; color: "#6060a0"; font.letterSpacing: 1 }
                        Item { Layout.fillWidth: true }
                        Row {
                            spacing: 8
                            Text { text: "H: "+coinHistory.filter(function(c){return c==="H"}).length
                                font.pixelSize: 10; color: "#70d890" }
                            Text { text: "T: "+coinHistory.filter(function(c){return c==="T"}).length
                                font.pixelSize: 10; color: "#f07878" }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 10
                        color: Qt.rgba(0.42,0.36,0.91,0.15)
                        border.color: Qt.rgba(0.42,0.36,0.91,0.30); border.width: 1
                        Text { anchors.centerIn: parent; text: coinFlipping ? "…" : "Flip Coin"
                            color: "#a898ff"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent
                            onClicked: {
                                if (coinFlipping) return
                                coinFlipping = true
                                coinTimer.restart()
                            }
                        }
                        Timer { id: coinTimer; interval: 400
                            onTriggered: {
                                var r = Math.random() < 0.5 ? "H" : "T"
                                coinResult  = r
                                coinHistory = [r].concat(coinHistory.slice(0,49))
                                coinFlipping = false
                            }
                        }
                    }

                    RowLayout {
                        visible: coinResult !== null
                        Text { text: coinResult === "H" ? "🟡" : "⚫"; font.pixelSize: 36 }
                        Text { text: coinResult === "H" ? "HEADS" : "TAILS"
                            color: coinResult === "H" ? "#f0d060" : "#c0c0c0"
                            font.pixelSize: 18; font.weight: Font.Light; leftPadding: 8 }
                    }
                }
            }

            // ── RANGE ─────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; radius: 16
                color: Qt.rgba(0,0,0,0.20); border.color: Qt.rgba(1,1,1,0.08); border.width: 1
                height: rangeSection.implicitHeight + 24

                ColumnLayout {
                    id: rangeSection
                    anchors { left:parent.left; right:parent.right; top:parent.top; margins:14 }
                    spacing: 10

                    Text { text: "🎯 RANGE"; font.pixelSize: 9; color: "#6060a0"; font.letterSpacing: 1 }

                    RowLayout {
                        spacing: 12
                        Column { spacing: 4; Layout.fillWidth: true
                            Text { text: "Min"; color: "#8888b8"; font.pixelSize: 11 }
                            StyledInput { width: parent.width; text: randMin; onTextChanged: randMin = text
                                inputMethodHints: Qt.ImhDigitsOnly }
                        }
                        Column { spacing: 4; Layout.fillWidth: true
                            Text { text: "Max"; color: "#8888b8"; font.pixelSize: 11 }
                            StyledInput { width: parent.width; text: randMax; onTextChanged: randMax = text
                                inputMethodHints: Qt.ImhDigitsOnly }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 10
                        color: Qt.rgba(0.24,0.78,0.47,0.15)
                        border.color: Qt.rgba(0.24,0.78,0.47,0.30); border.width: 1
                        Text { anchors.centerIn: parent; text: "Pick"; color: "#70d890"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent
                            onClicked: {
                                var mn = parseInt(randMin), mx = parseInt(randMax)
                                if (isNaN(mn)||isNaN(mx)||mn>=mx) return
                                var r = Math.floor(Math.random()*(mx-mn+1))+mn
                                randResult  = r
                                randHistory = [r].concat(randHistory.slice(0,4))
                            }
                        }
                    }

                    Text { visible: randResult !== null
                        text: String(randResult)
                        color: "#d8d0ff"; font.pixelSize: 40; font.weight: Font.Light
                        Layout.alignment: Qt.AlignHCenter }
                }
            }

            // ── MATH PRACTICE ─────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; radius: 16
                color: Qt.rgba(0,0,0,0.20); border.color: Qt.rgba(1,1,1,0.08); border.width: 1
                height: mathSection.implicitHeight + 24

                ColumnLayout {
                    id: mathSection
                    anchors { left:parent.left; right:parent.right; top:parent.top; margins:14 }
                    spacing: 10

                    RowLayout {
                        Text { text: "🧮 MATH PRACTICE"; font.pixelSize: 9; color: "#6060a0"; font.letterSpacing: 1 }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: mathScore.right + mathScore.wrong > 0
                            text: "✓ "+mathScore.right+" / ✗ "+mathScore.wrong
                                  + "  " + Math.round(mathScore.right/(mathScore.right+mathScore.wrong)*100) + "%"
                            font.pixelSize: 10; color: "#8080b8"
                        }
                    }

                    // Difficulty pills
                    Row { spacing: 6
                        Repeater { model: difficulties
                            delegate: UnitPill { label: modelData; active: difficulty === modelData
                                onClicked: { difficulty = modelData; currentProb = null; mathChecked = null } }
                        }
                    }

                    // Start / question
                    Rectangle {
                        visible: currentProb === null
                        Layout.fillWidth: true; height: 44; radius: 10
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#5b50f2" }
                            GradientStop { position: 1.0; color: "#7c3aed" }
                        }
                        Text { anchors.centerIn: parent; text: "Start — " + difficulty; color: "#fff"; font.pixelSize: 13 }
                        MouseArea { anchors.fill: parent; onClicked: newMathProblem() }
                    }

                    // Question display
                    Rectangle {
                        visible: currentProb !== null
                        Layout.fillWidth: true; height: 72; radius: 12
                        color: mathChecked === true  ? Qt.rgba(0.47,0.85,0.49,0.08) :
                               mathChecked === false ? Qt.rgba(0.88,0.22,0.39,0.08) :
                               Qt.rgba(1,1,1,0.06)
                        border.color: mathChecked === true  ? Qt.rgba(0.47,0.85,0.49,0.35) :
                                      mathChecked === false ? Qt.rgba(0.88,0.22,0.39,0.30) :
                                      Qt.rgba(1,1,1,0.10); border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: currentProb ? currentProb.q : ""
                            color: window ? window.textColor : "#f0f0ff"
                            font.pixelSize: 22; font.weight: Font.DemiBold
                            font.family: "JetBrains Mono"
                        }
                    }

                    // Answer input + check
                    RowLayout {
                        visible: currentProb !== null && mathChecked === null
                        Layout.fillWidth: true; spacing: 8

                        StyledInput {
                            Layout.fillWidth: true
                            placeholderText: "Your answer…"
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            onTextChanged: mathAnswer = text
                            Keys.onReturnPressed: checkAnswer()
                        }

                        Rectangle {
                            width: 70; height: 42; radius: 10
                            color: Qt.rgba(0.42,0.36,0.91,0.15)
                            border.color: Qt.rgba(0.42,0.36,0.91,0.30); border.width: 1
                            Text { anchors.centerIn: parent; text: "Check"; color: "#a29bfe"; font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent; onClicked: checkAnswer() }
                        }
                    }

                    // Result + next
                    RowLayout {
                        visible: mathChecked !== null
                        Layout.fillWidth: true; spacing: 8

                        Text {
                            text: mathChecked ? "✓ Correct!" + (streak>=3 ? "  🔥"+streak : "") : "✗ Answer: " + (currentProb ? currentProb.a : "")
                            color: mathChecked ? "#70d890" : "#f07878"; font.pixelSize: 13
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 70; height: 36; radius: 9
                            color: Qt.rgba(0.42,0.36,0.91,0.15)
                            border.color: Qt.rgba(0.42,0.36,0.91,0.30); border.width: 1
                            Text { anchors.centerIn: parent; text: "Next →"; color: "#a29bfe"; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; onClicked: newMathProblem() }
                        }
                    }

                    // Streak display
                    Text {
                        visible: streak >= 5
                        text: "🔥 Streak: " + streak
                        color: "#f0a060"; font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            Item { height: 10 }
        }
    }
}
