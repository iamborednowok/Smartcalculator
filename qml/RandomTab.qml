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
    property bool   showHint:     false
    property string currentTag:   ""

    readonly property var difficulties: ["Random","Easy","Hard","Nightmare","Impossible"]
    readonly property var diceTypes:    [4,6,8,10,12,20,100]

    readonly property var diffColors: ({
        "Random":     "#a090e8",
        "Easy":       "#70d890",
        "Hard":       "#f0a060",
        "Nightmare":  "#f07070",
        "Impossible": "#c090f8"
    })

    // ── Rich problem pool ──────────────────────────────────────────────
    function rn(range, min) { return Math.floor(Math.random() * range) + (min || 1) }
    function ri(n) { return Math.floor(Math.random() * n) }
    function fix(n, d) { return parseFloat(n.toFixed(d !== undefined ? d : 4)) }

    function getProblemPool() {
        return [
            // ── EASY ──────────────────────────────────────────────────
            { tag:"Addition",       level:"Easy",       gen: function() { var a=rn(50),b=rn(50); return {q:a+" + "+b, a:a+b} }},
            { tag:"Subtraction",    level:"Easy",       gen: function() { var a=rn(50,10),b=rn(a-1,1); return {q:a+" − "+b, a:a-b} }},
            { tag:"Multiplication", level:"Easy",       gen: function() { var a=rn(12,2),b=rn(12,2); return {q:a+" × "+b, a:a*b} }},
            { tag:"Division",       level:"Easy",       gen: function() { var b=rn(9,2),a=b*rn(9,1); return {q:a+" ÷ "+b, a:a/b} }},
            { tag:"Squares",        level:"Easy",       gen: function() { var n=rn(12,2); return {q:n+"²", a:n*n} }},
            { tag:"Square Root",    level:"Easy",       gen: function() { var ns=[1,4,9,16,25,36,49,64,81,100,121,144]; var n=ns[ri(12)]; return {q:"√"+n, a:Math.sqrt(n)} }},
            { tag:"Percentage",     level:"Easy",       gen: function() { var a=rn(80,10),r=[5,10,15,20,25,50][ri(6)]; return {q:r+"% of "+a, a:a*r/100} }},
            { tag:"Times Table",    level:"Easy",       gen: function() { var n=rn(12,2),m=rn(12,1); return {q:"What is "+n+" × "+m+"?", a:n*m} }},
            { tag:"Rounding",       level:"Easy",       gen: function() { var n=rn(990,10)+ri(9)/10,t=[1,5,10][ri(3)]; var r=Math.round(n/t)*t; return {q:"Round "+n.toFixed(1)+" to nearest "+t, a:r, hint:"Look at the digit after the rounding position"} }},
            { tag:"Negatives",      level:"Easy",       gen: function() { var a=rn(20,1),b=rn(15,1); return {q:"−"+a+" + "+b, a:b-a} }},

            // ── HARD ──────────────────────────────────────────────────
            { tag:"Addition",       level:"Hard",       gen: function() { var a=rn(9000,1000),b=rn(9000,1000); return {q:a+" + "+b, a:a+b} }},
            { tag:"Multiplication", level:"Hard",       gen: function() { var a=rn(50,10),b=rn(20,5); return {q:a+" × "+b, a:a*b} }},
            { tag:"BODMAS",         level:"Hard",       gen: function() { var a=rn(10,2),b=rn(8,2),c=rn(6,2),d=rn(4,1); return {q:a+" × "+b+" + "+c+" × "+d, a:a*b+c*d, hint:"Multiply first, then add"} }},
            { tag:"Squares",        level:"Hard",       gen: function() { var n=rn(25,10); return {q:n+"²", a:n*n} }},
            { tag:"Algebra",        level:"Hard",       gen: function() { var x=rn(15,1),m=rn(5,2),c=rn(10,0); return {q:m+"x + "+c+" = "+(m*x+c)+"  →  x = ?", a:x, hint:"Subtract "+c+", then divide by "+m} }},
            { tag:"% Change",       level:"Hard",       gen: function() { var a=rn(80,20),p=[10,15,20,25,30][ri(5)],up=Math.random()<0.5; var r=up ? a*(1+p/100) : a*(1-p/100); return {q:(up?"Increase ":"Decrease ")+a+" by "+p+"%", a:fix(r,2)} }},
            { tag:"Decimals",       level:"Hard",       gen: function() { var a=rn(9,1)+ri(9)/10,b=rn(9,1)+ri(9)/10; return {q:fix(a,1)+" × "+fix(b,1), a:fix(a*b,2)} }},
            { tag:"Missing No.",    level:"Hard",       gen: function() { var a=rn(20,5),b=rn(10,2),c=a*b; return {q:a+" × __ = "+c, a:b, hint:"What times "+a+" = "+c+"?"} }},

            // ── NIGHTMARE ─────────────────────────────────────────────
            { tag:"Multiplication", level:"Nightmare",  gen: function() { var a=rn(900,100),b=rn(90,10); return {q:a+" × "+b, a:a*b} }},
            { tag:"BODMAS",         level:"Nightmare",  gen: function() { var a=rn(20,5),b=rn(15,3),c=rn(10,2),d=rn(8,2); return {q:"("+a+" + "+b+") × ("+c+" − "+d+")", a:(a+b)*(c-d), hint:"Solve each bracket first"} }},
            { tag:"Fractions",      level:"Nightmare",  gen: function() { var a=rn(8,2),b=rn(8,2),c=rn(8,2),d=rn(8,2); return {q:a+"/"+b+" + "+c+"/"+d, a:fix((a*d+b*c)/(b*d)), hint:"Common denominator is "+b*d} }},
            { tag:"Cube Root",      level:"Nightmare",  gen: function() { var n=[2,3,4,5,6,7,8,9,10][ri(9)]; return {q:"∛"+(n*n*n), a:n} }},
            { tag:"Geometric Seq.", level:"Nightmare",  gen: function() { var a=rn(5,1),r=rn(4,2),n=rn(4,3); var s=a*(Math.pow(r,n)-1)/(r-1); return {q:"Geo sum: "+a+"+"+a*r+"+"+a*r*r+"+ … ("+n+" terms)", a:fix(s,2), hint:"S = a(rⁿ−1)/(r−1)"} }},
            { tag:"Quadratic",      level:"Nightmare",  gen: function() { var x1=rn(8,1),x2=rn(6,1); var b=-(x1+x2),c=x1*x2; var bs=(b>=0?"+":"")+b,cs=(c>=0?"+":"")+c; return {q:"x²"+bs+"x"+cs+"=0  larger x=?", a:Math.max(x1,x2), hint:"Find two numbers that multiply to "+c+" and add to "+b} }},
            { tag:"Simultaneous",   level:"Nightmare",  gen: function() { var x=rn(8,1),y=rn(8,1),a=rn(4,2),b=rn(4,2); var s=a*x+b*y,d=x-y; return {q:a+"x + "+b+"y = "+s+",  x − y = "+d+"  →  x = ?", a:x, hint:"Substitute x = y + "+d} }},

            // ── IMPOSSIBLE ────────────────────────────────────────────
            { tag:"Powers",         level:"Impossible", gen: function() { var b=[2,3,4,5,6][ri(5)],e=[6,7,8,9,10,11,12][ri(7)]; return {q:b+"^"+e, a:Math.pow(b,e)} }},
            { tag:"Logarithm",      level:"Impossible", gen: function() { var bases=[2,3,4,5,8,10],b=bases[ri(6)],e=rn(6,2); return {q:"log₍"+b+"₎("+Math.pow(b,e)+")", a:e, hint:"log base "+b+" asks: '"+b+" to what power = "+Math.pow(b,e)+"?'"} }},
            { tag:"Trig",           level:"Impossible", gen: function() {
                var fn=["sin","cos","tan"][ri(3)]
                var sinP=[[0,0],[30,0.5],[45,fix(Math.SQRT2/2)],[60,fix(Math.sqrt(3)/2)],[90,1]]
                var cosP=[[0,1],[30,fix(Math.sqrt(3)/2)],[45,fix(Math.SQRT2/2)],[60,0.5],[90,0]]
                var tanP=[[0,0],[30,fix(1/Math.sqrt(3))],[45,1],[60,fix(Math.sqrt(3))]]
                if(fn==="sin"){ var p=sinP[ri(5)]; return {q:"sin("+p[0]+"°)", a:p[1], hint:"Use the unit circle"} }
                if(fn==="cos"){ var p=cosP[ri(5)]; return {q:"cos("+p[0]+"°)", a:p[1], hint:"Use the unit circle"} }
                var p=tanP[ri(4)]; return {q:"tan("+p[0]+"°)", a:p[1], hint:"tan = sin/cos"}
            }},
            { tag:"Arith. Series",  level:"Impossible", gen: function() { var a=rn(15,1),d=rn(10,2),n=rn(5,4); var s=n*(2*a+(n-1)*d)/2; return {q:"Sum: "+a+"+"+(a+d)+"+"+(a+2*d)+"+ … ("+n+" terms)", a:s, hint:"S = n/2 × (2a + (n−1)d)"} }},
            { tag:"Modular",        level:"Impossible", gen: function() { var a=rn(90,10),b=rn(9,2); return {q:a+" mod "+b, a:a%b, hint:"Find the remainder after dividing "+a+" by "+b} }},
            { tag:"Determinant",    level:"Impossible", gen: function() { var a=rn(6,1),b=rn(6,1),c=rn(6,1),d=rn(6,1); return {q:"|"+a+" "+b+"|\n|"+c+" "+d+"|  →  det=?", a:a*d-b*c, hint:"det = ad − bc"} }},
        ]
    }

    function newMathProblem() {
        showHint   = false
        mathAnswer = ""
        mathChecked = null

        var pool = getProblemPool()
        var filtered

        if (difficulty === "Random") {
            filtered = pool
        } else {
            filtered = []
            for (var i = 0; i < pool.length; i++) {
                if (pool[i].level === difficulty) filtered.push(pool[i])
            }
        }

        if (filtered.length === 0) return

        var entry  = filtered[Math.floor(Math.random() * filtered.length)]
        var result = entry.gen()

        currentTag  = (difficulty === "Random" ? "[" + entry.level + "] " : "") + entry.tag
        currentProb = { q: result.q, a: result.a, hint: result.hint || "" }
    }

    function checkAnswer() {
        if (!currentProb || mathAnswer.trim() === "") return
        var user    = parseFloat(mathAnswer)
        var correct = Math.abs(user - currentProb.a) < 0.01
        mathChecked = correct
        if (correct) {
            mathScore = {right: mathScore.right+1, wrong: mathScore.wrong}
            streak++
            if (window) window.showToast("✓ Correct!" + (streak >= 3 ? "  🔥" : ""), true)
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

            // ── DICE ───────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; radius: 16
                color: Theme.sectionBg; border.color: Theme.sectionBdr; border.width: 1
                height: diceSection.implicitHeight + 24

                ColumnLayout {
                    id: diceSection
                    anchors { left:parent.left; right:parent.right; top:parent.top; margins:14 }
                    spacing: 10

                    RowLayout {
                        Text { text: "🎲 DICE ROLLER"; font.pixelSize: Math.round(9 * Theme.scale); color: Theme.text3; font.letterSpacing: 1 }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 52; height: 20; radius: 8
                            color: Qt.rgba(0.42,0.36,0.91,0.15)
                            border.color: Qt.rgba(0.42,0.36,0.91,0.35); border.width: 1
                            Text { anchors.centerIn: parent; text: diceCount+"d"+diceType
                                font.pixelSize: Math.round(9 * Theme.scale); color: Theme.accent2; font.family: Theme.fontMono }
                        }
                    }

                    Row { spacing: 6
                        Repeater {
                            model: diceTypes
                            delegate: UnitPill { label: "d"+modelData; active: diceType===modelData
                                onClicked: diceType = modelData }
                        }
                    }

                    RowLayout {
                        Text { text: "Count:"; font.pixelSize: Math.round(11 * Theme.scale); color: Theme.text2 }
                        Row { spacing: 5
                            Repeater { model: [1,2,3,4,5,6]
                                delegate: UnitPill { label: ""+modelData; active: diceCount===modelData
                                    onClicked: diceCount = modelData; width: 30 }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 10
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#5b50f2" }
                            GradientStop { position: 1.0; color: "#7c3aed" }
                        }
                        Text { anchors.centerIn: parent; text: "Roll!"; color: "#fff"; font.pixelSize: Math.round(13 * Theme.scale); font.weight: Font.DemiBold }
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
                                    color: Theme.text; font.pixelSize: Math.round(18 * Theme.scale); font.weight: Font.Light }
                            }
                        }
                    }
                    Text {
                        visible: diceResults.length > 1
                        text: "Sum: " + diceResults.reduce(function(a,b){return a+b},0)
                            + "  Min: " + Math.min.apply(null, diceResults)
                            + "  Max: " + Math.max.apply(null, diceResults)
                        font.pixelSize: Math.round(11 * Theme.scale); color: Theme.text2
                    }
                }
            }

            // ── COIN ───────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; radius: 16
                color: Theme.sectionBg; border.color: Theme.sectionBdr; border.width: 1
                height: coinSection.implicitHeight + 24

                ColumnLayout {
                    id: coinSection
                    anchors { left:parent.left; right:parent.right; top:parent.top; margins:14 }
                    spacing: 10

                    RowLayout {
                        Text { text: "🪙 COIN"; font.pixelSize: Math.round(9 * Theme.scale); color: Theme.text3; font.letterSpacing: 1 }
                        Item { Layout.fillWidth: true }
                        Row {
                            spacing: 8
                            Text { text: "H: "+coinHistory.filter(function(c){return c==="H"}).length
                                font.pixelSize: Math.round(10 * Theme.scale); color: "#70d890" }
                            Text { text: "T: "+coinHistory.filter(function(c){return c==="T"}).length
                                font.pixelSize: Math.round(10 * Theme.scale); color: "#f07878" }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 10
                        color: Qt.rgba(0.42,0.36,0.91,0.15)
                        border.color: Qt.rgba(0.42,0.36,0.91,0.30); border.width: 1
                        Text { anchors.centerIn: parent; text: coinFlipping ? "…" : "Flip Coin"
                            color: Theme.accent2; font.pixelSize: Math.round(13 * Theme.scale); font.weight: Font.DemiBold }
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
                        Text { text: coinResult === "H" ? "🟡" : "⚫"; font.pixelSize: Math.round(36 * Theme.scale) }
                        Text { text: coinResult === "H" ? "HEADS" : "TAILS"
                            color: coinResult === "H" ? "#f0d060" : "#c0c0c0"
                            font.pixelSize: Math.round(18 * Theme.scale); font.weight: Font.Light; leftPadding: 8 }
                    }
                }
            }

            // ── RANGE ──────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; radius: 16
                color: Theme.sectionBg; border.color: Theme.sectionBdr; border.width: 1
                height: rangeSection.implicitHeight + 24

                ColumnLayout {
                    id: rangeSection
                    anchors { left:parent.left; right:parent.right; top:parent.top; margins:14 }
                    spacing: 10

                    Text { text: "🎯 RANGE"; font.pixelSize: Math.round(9 * Theme.scale); color: Theme.text3; font.letterSpacing: 1 }

                    RowLayout {
                        spacing: 12
                        Column { spacing: 4; Layout.fillWidth: true
                            Text { text: "Min"; color: Theme.text2; font.pixelSize: Math.round(11 * Theme.scale) }
                            StyledInput { width: parent.width; text: randMin; onTextChanged: randMin = text
                                inputMethodHints: Qt.ImhDigitsOnly }
                        }
                        Column { spacing: 4; Layout.fillWidth: true
                            Text { text: "Max"; color: Theme.text2; font.pixelSize: Math.round(11 * Theme.scale) }
                            StyledInput { width: parent.width; text: randMax; onTextChanged: randMax = text
                                inputMethodHints: Qt.ImhDigitsOnly }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 10
                        color: Qt.rgba(0.24,0.78,0.47,0.15)
                        border.color: Qt.rgba(0.24,0.78,0.47,0.30); border.width: 1
                        Text { anchors.centerIn: parent; text: "Pick"; color: "#70d890"; font.pixelSize: Math.round(13 * Theme.scale); font.weight: Font.DemiBold }
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
                        color: Theme.text; font.pixelSize: Math.round(40 * Theme.scale); font.weight: Font.Light
                        Layout.alignment: Qt.AlignHCenter }
                }
            }

            // ── MATH PRACTICE ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; radius: 16
                color: Theme.sectionBg; border.color: Theme.sectionBdr; border.width: 1
                height: mathSection.implicitHeight + 24

                ColumnLayout {
                    id: mathSection
                    anchors { left:parent.left; right:parent.right; top:parent.top; margins:14 }
                    spacing: 10

                    // Header row
                    RowLayout {
                        Text { text: "🧮 MATH PRACTICE"; font.pixelSize: Math.round(9 * Theme.scale); color: Theme.text3; font.letterSpacing: 1 }
                        Item { Layout.fillWidth: true }
                        // Reset score
                        Rectangle {
                            visible: mathScore.right + mathScore.wrong > 0
                            width: resetLbl.implicitWidth + 14; height: 20; radius: 8
                            color: "transparent"
                            border.color: Qt.rgba(0.96,0.25,0.37,0.25); border.width: 1
                            Text { id: resetLbl; anchors.centerIn: parent; text: "reset"; font.pixelSize: Math.round(8 * Theme.scale); color: "#F43F5E" }
                            MouseArea { anchors.fill: parent; onClicked: {
                                mathScore = {right:0, wrong:0}; streak = 0
                            }}
                        }
                    }

                    // Score display
                    RowLayout {
                        visible: mathScore.right + mathScore.wrong > 0
                        spacing: 10
                        Text {
                            text: "✓ " + mathScore.right + "  ✗ " + mathScore.wrong
                            font.pixelSize: Math.round(11 * Theme.scale); color: "#8080b8"
                        }
                        Rectangle {
                            width: scorePct.implicitWidth + 12; height: 18; radius: 9
                            color: {
                                var pct = mathScore.right/(mathScore.right+mathScore.wrong)
                                return pct >= 0.8 ? Qt.rgba(0.27,0.85,0.49,0.14) :
                                       pct >= 0.5 ? Qt.rgba(0.95,0.62,0.07,0.14) :
                                                    Qt.rgba(0.88,0.22,0.39,0.14)
                            }
                            Text {
                                id: scorePct; anchors.centerIn: parent
                                text: Math.round(mathScore.right/(mathScore.right+mathScore.wrong)*100) + "%"
                                font.pixelSize: Math.round(9 * Theme.scale); font.family: Theme.fontSans
                                color: {
                                    var pct = mathScore.right/(mathScore.right+mathScore.wrong)
                                    return pct >= 0.8 ? "#70d890" : pct >= 0.5 ? "#F59E0B" : "#f07878"
                                }
                            }
                        }
                        // Streak badge
                        Rectangle {
                            visible: streak >= 3
                            width: streakLbl.implicitWidth + 14; height: 18; radius: 9
                            color: Qt.rgba(0.95,0.62,0.07,0.12)
                            border.color: Qt.rgba(0.95,0.62,0.07,0.30); border.width: 1
                            Text { id: streakLbl; anchors.centerIn: parent; text: "🔥 " + streak; font.pixelSize: Math.round(9 * Theme.scale); color: "#f0a060" }
                        }
                    }

                    // Difficulty pills
                    Flow { spacing: 6
                        Repeater { model: difficulties
                            delegate: Rectangle {
                                height: 26; width: diffLbl.implicitWidth + 16; radius: 13
                                color: difficulty === modelData
                                       ? Qt.rgba(0.42,0.36,0.91,0.22)
                                       : Qt.rgba(1,1,1,0.06)
                                border.color: difficulty === modelData
                                              ? Qt.rgba(0.67,0.55,1.0,0.50)
                                              : Qt.rgba(1,1,1,0.14)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Row {
                                    anchors.centerIn: parent; spacing: 4
                                    Text {
                                        text: modelData === "Random" ? "🎲"
                                            : modelData === "Easy"      ? "🟢"
                                            : modelData === "Hard"      ? "🟠"
                                            : modelData === "Nightmare" ? "🔴" : "💀"
                                        font.pixelSize: Math.round(9 * Theme.scale)
                                    }
                                    Text {
                                        id: diffLbl; text: modelData
                                        font.pixelSize: Math.round(10 * Theme.scale); font.family: Theme.fontSans
                                        color: difficulty === modelData ? Theme.text : Theme.text3
                                    }
                                }
                                MouseArea { anchors.fill: parent; onClicked: {
                                    difficulty = modelData; currentProb = null; mathChecked = null; showHint = false
                                }}
                            }
                        }
                    }

                    // Start button (no current problem)
                    Rectangle {
                        visible: currentProb === null
                        Layout.fillWidth: true; height: 44; radius: 10
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#5b50f2" }
                            GradientStop { position: 1.0; color: "#7c3aed" }
                        }
                        Text { anchors.centerIn: parent; text: "Start — " + difficulty; color: "#fff"; font.pixelSize: Math.round(13 * Theme.scale) }
                        MouseArea { anchors.fill: parent; onClicked: newMathProblem() }
                    }

                    // Problem tag chip
                    Rectangle {
                        visible: currentProb !== null && currentTag !== ""
                        height: 22; width: tagLbl.implicitWidth + 16; radius: 11
                        color: Qt.rgba(0.42,0.36,0.91,0.12)
                        border.color: Qt.rgba(0.67,0.55,1.0,0.28); border.width: 1
                        Text { id: tagLbl; anchors.centerIn: parent; text: currentTag; font.pixelSize: Math.round(9 * Theme.scale); color: Theme.accent2; font.family: Theme.fontSans }
                    }

                    // Question display
                    Rectangle {
                        visible: currentProb !== null
                        Layout.fillWidth: true
                        height: Math.max(72, questionTxt.implicitHeight + 28)
                        radius: 12
                        color: mathChecked === true  ? Qt.rgba(0.47,0.85,0.49,0.08) :
                               mathChecked === false ? Qt.rgba(0.88,0.22,0.39,0.08) :
                               Qt.rgba(1,1,1,0.06)
                        border.color: mathChecked === true  ? Qt.rgba(0.47,0.85,0.49,0.35) :
                                      mathChecked === false ? Qt.rgba(0.88,0.22,0.39,0.30) :
                                      Qt.rgba(1,1,1,0.10); border.width: 1

                        Text {
                            id: questionTxt
                            anchors.centerIn: parent
                            anchors.margins: 14
                            width: parent.width - 28
                            text: currentProb ? currentProb.q : ""
                            color: Theme.text
                            font.pixelSize: currentProb && currentProb.q.length > 20 ? 17 : 22
                            font.weight: Font.DemiBold
                            font.family: Theme.fontMono
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }

                    // Hint
                    Rectangle {
                        visible: showHint && currentProb !== null && (currentProb.hint || "") !== ""
                        Layout.fillWidth: true
                        height: visible ? hintTxt.implicitHeight + 16 : 0
                        clip: true
                        radius: 10
                        color: Qt.rgba(0.95,0.62,0.07,0.08)
                        border.color: Qt.rgba(0.95,0.62,0.07,0.28); border.width: 1
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        Text {
                            id: hintTxt
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                            text: "💡 " + (currentProb ? currentProb.hint || "" : "")
                            color: "#F59E0B"; font.pixelSize: Math.round(11 * Theme.scale); font.family: Theme.fontSans
                            wrapMode: Text.WordWrap
                        }
                    }

                    // Answer input row
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

                        // Hint button
                        Rectangle {
                            visible: currentProb !== null && (currentProb.hint || "") !== ""
                            width: 52; height: 42; radius: 10
                            color: showHint ? Qt.rgba(0.95,0.62,0.07,0.18) : Qt.rgba(0.95,0.62,0.07,0.08)
                            border.color: Qt.rgba(0.95,0.62,0.07,0.35); border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text { anchors.centerIn: parent; text: "hint"; color: "#F59E0B"; font.pixelSize: Math.round(11 * Theme.scale) }
                            MouseArea { anchors.fill: parent; onClicked: showHint = !showHint }
                        }

                        // Check button
                        Rectangle {
                            width: 64; height: 42; radius: 10
                            color: Qt.rgba(0.42,0.36,0.91,0.15)
                            border.color: Qt.rgba(0.42,0.36,0.91,0.30); border.width: 1
                            Text { anchors.centerIn: parent; text: "Check"; color: "#a29bfe"; font.pixelSize: Math.round(12 * Theme.scale) }
                            MouseArea { anchors.fill: parent; onClicked: checkAnswer() }
                        }
                    }

                    // Result row
                    RowLayout {
                        visible: mathChecked !== null
                        Layout.fillWidth: true; spacing: 8

                        Text {
                            text: mathChecked ? "✓ Correct!" + (streak >= 3 ? "  🔥" + streak : "") : "✗ Answer: " + (currentProb ? currentProb.a : "")
                            color: mathChecked ? "#70d890" : "#f07878"; font.pixelSize: Math.round(13 * Theme.scale)
                            Layout.fillWidth: true
                        }

                        // Skip button (when wrong, show "skip")
                        Rectangle {
                            visible: !mathChecked
                            width: 56; height: 34; radius: 9
                            color: Qt.rgba(1,1,1,0.06)
                            border.color: Qt.rgba(1,1,1,0.14); border.width: 1
                            Text { anchors.centerIn: parent; text: "skip"; color: Theme.text3; font.pixelSize: Math.round(11 * Theme.scale) }
                            MouseArea { anchors.fill: parent; onClicked: newMathProblem() }
                        }

                        Rectangle {
                            width: 70; height: 36; radius: 9
                            color: Qt.rgba(0.42,0.36,0.91,0.15)
                            border.color: Qt.rgba(0.42,0.36,0.91,0.30); border.width: 1
                            Text { anchors.centerIn: parent; text: "Next →"; color: "#a29bfe"; font.pixelSize: Math.round(11 * Theme.scale) }
                            MouseArea { anchors.fill: parent; onClicked: newMathProblem() }
                        }
                    }

                    // Skip button (when unanswered)
                    RowLayout {
                        visible: currentProb !== null && mathChecked === null
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 56; height: 24; radius: 8
                            color: "transparent"
                            border.color: Qt.rgba(1,1,1,0.12); border.width: 1
                            Text { anchors.centerIn: parent; text: "skip"; color: Theme.text3; font.pixelSize: Math.round(9 * Theme.scale) }
                            MouseArea { anchors.fill: parent; onClicked: newMathProblem() }
                        }
                    }
                }
            }

            Item { height: 10 }
        }
    }
}
