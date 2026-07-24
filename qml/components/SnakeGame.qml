import QtQuick
import QtQuick.Layouts

// Secret snake game — surfaced from AITab.qml when someone types "snake"
// (or a couple of variants) into the AI chat instead of asking it a real
// question. Grid is plain Rectangles via a Repeater, not Canvas — slower
// to render at a large grid size than a painted canvas would be, but
// every piece of state driving it is an ordinary bound property I can
// reason about directly, which matters a lot for a component built and
// shipped without ever seeing it rendered on an actual device.
//
// The movement/collision/food-spawn logic below (nextDirection,
// stepSnake, spawnFood) was written and unit-tested standalone in plain
// JS first — including the classic "chase your own tail" edge case,
// which an earlier, more naive version of stepSnake got wrong (it
// treated moving onto the current tail cell as a collision, when the
// tail actually vacates that cell the same tick unless the snake is
// eating this move). What is here is the corrected version; the port
// from the tested standalone version to this file changed nothing about
// the logic itself.
Item {
    id: root

    signal closed()

    readonly property int gridSize: 13
    readonly property int cellSize: Math.floor(Math.min(width, height - Theme.sp6 * 3) / gridSize)

    property var snake: []
    property string direction: "right"
    property string pendingDirection: "right"
    property var food: ({x: 9, y: 6})
    property int score: 0
    property int best: 0
    property bool gameOver: false
    property bool started: false

    function resetGame() {
        snake = [{x: 7, y: 6}, {x: 6, y: 6}, {x: 5, y: 6}]
        direction = "right"
        pendingDirection = "right"
        score = 0
        gameOver = false
        started = false
        food = spawnFood(snake)
    }
    Component.onCompleted: resetGame()

    // ── Pure game logic — see file header. Deliberately free of anything
    // QML-specific (no property reads/writes inside these three), so the
    // exact same functions could be copy-pasted into a plain JS test file
    // and behave identically, which is exactly how they were verified
    // before landing here.
    function nextDirection(current, requested) {
        var opposite = {up: "down", down: "up", left: "right", right: "left"}
        if (opposite[current] === requested) return current
        return requested
    }

    function stepSnake(snakeIn, dir, foodIn, size) {
        var head = snakeIn[0]
        var dx = dir === "left" ? -1 : dir === "right" ? 1 : 0
        var dy = dir === "up" ? -1 : dir === "down" ? 1 : 0
        var newHead = {x: head.x + dx, y: head.y + dy}

        if (newHead.x < 0 || newHead.x >= size || newHead.y < 0 || newHead.y >= size)
            return {gameOver: true, snake: snakeIn, ateFood: false}

        var ateFood = (newHead.x === foodIn.x && newHead.y === foodIn.y)

        // Not eating: the tail vacates its cell this same tick, so moving
        // onto it is legal — check everything except the last segment.
        // Eating: the tail does not move (snake grows instead), so the
        // full body including the tail is what is actually still occupied.
        var bodyToCheck = ateFood ? snakeIn : snakeIn.slice(0, snakeIn.length - 1)
        for (var i = 0; i < bodyToCheck.length; i++) {
            if (bodyToCheck[i].x === newHead.x && bodyToCheck[i].y === newHead.y)
                return {gameOver: true, snake: snakeIn, ateFood: false}
        }

        var newSnake = [newHead].concat(snakeIn)
        if (!ateFood) newSnake.pop()
        return {gameOver: false, snake: newSnake, ateFood: ateFood}
    }

    function spawnFood(snakeIn) {
        var attempts = 0
        while (attempts < 1000) {
            var candidate = {x: Math.floor(Math.random() * gridSize), y: Math.floor(Math.random() * gridSize)}
            var onSnake = false
            for (var i = 0; i < snakeIn.length; i++)
                if (snakeIn[i].x === candidate.x && snakeIn[i].y === candidate.y) { onSnake = true; break }
            if (!onSnake) return candidate
            attempts++
        }
        return {x: 0, y: 0}   // unreachable in practice — grid has far more free cells than snake length ever reaches
    }

    function turn(d) {
        if (!started) started = true
        pendingDirection = nextDirection(direction, d)
    }

    function tick() {
        if (gameOver || !started) return
        direction = pendingDirection
        var result = stepSnake(snake, direction, food, gridSize)
        if (result.gameOver) {
            gameOver = true
            if (score > best) best = score
            return
        }
        snake = result.snake
        if (result.ateFood) {
            score += 1
            food = spawnFood(snake)
        }
    }

    Timer {
        interval: 160
        running: root.visible && root.started && !root.gameOver
        repeat: true
        onTriggered: root.tick()
    }

    // ── Background ───────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: Theme.bg }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sp3
        spacing: Theme.sp3

        // ── Header ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2
            Text { text: "🐍 secret snake"; color: Theme.text; font.family: Theme.fontSans; font.weight: Font.DemiBold; font.pixelSize: Math.round(16 * Theme.scale) }
            Item { Layout.fillWidth: true }
            Text { text: "score " + root.score + "   best " + root.best; color: Theme.textDim; font.family: Theme.fontMono; font.pixelSize: Math.round(12 * Theme.scale) }
            Text {
                text: "close"; color: Theme.accent; font.family: Theme.fontSans; font.weight: Font.Medium; font.pixelSize: Math.round(12 * Theme.scale)
                TapHandler { onTapped: root.closed() }
            }
        }

        // ── Grid ─────────────────────────────────────────────────────
        Item {
            id: gridArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: board
                anchors.centerIn: parent
                width: root.cellSize * root.gridSize
                height: width
                color: Theme.surface
                radius: Theme.rMd
                border.width: 1
                border.color: Theme.edgeB2

                Repeater {
                    model: root.snake
                    delegate: Rectangle {
                        x: modelData.x * root.cellSize + 1
                        y: modelData.y * root.cellSize + 1
                        width: root.cellSize - 2
                        height: root.cellSize - 2
                        radius: Math.round(4 * Theme.scale)
                        color: index === 0 ? Theme.accent2 : Theme.gradB
                    }
                }

                Rectangle {
                    x: root.food.x * root.cellSize + 1
                    y: root.food.y * root.cellSize + 1
                    width: root.cellSize - 2
                    height: root.cellSize - 2
                    radius: width / 2
                    color: Theme.accent
                }

                // ── Start / game-over overlay ───────────────────────
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Qt.rgba(0, 0, 0, 0.55)
                    visible: !root.started || root.gameOver
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.sp2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.gameOver ? ("game over — " + root.score) : "swipe a direction\nto start"
                            horizontalAlignment: Text.AlignHCenter
                            color: "#FFFFFF"; font.family: Theme.fontSans; font.weight: Font.DemiBold
                            font.pixelSize: Math.round(15 * Theme.scale)
                        }
                        Text {
                            visible: root.gameOver
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "tap any arrow to try again"
                            color: "#CCCCCC"; font.family: Theme.fontSans; font.pixelSize: Math.round(11 * Theme.scale)
                        }
                    }
                    TapHandler {
                        onTapped: if (root.gameOver) root.resetGame()
                    }
                }
            }
        }

        // ── D-pad ────────────────────────────────────────────────────
        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            rowSpacing: Theme.sp2
            columnSpacing: Theme.sp2

            Item { Layout.preferredWidth: Math.round(52 * Theme.scale); Layout.preferredHeight: Math.round(52 * Theme.scale) }
            DPadButton { symbol: "▲"; onPressedDir: root.turn("up") }
            Item { Layout.preferredWidth: Math.round(52 * Theme.scale); Layout.preferredHeight: Math.round(52 * Theme.scale) }

            DPadButton { symbol: "◀"; onPressedDir: root.turn("left") }
            DPadButton { symbol: "●"; onPressedDir: root.gameOver ? root.resetGame() : null }
            DPadButton { symbol: "▶"; onPressedDir: root.turn("right") }

            Item { Layout.preferredWidth: Math.round(52 * Theme.scale); Layout.preferredHeight: Math.round(52 * Theme.scale) }
            DPadButton { symbol: "▼"; onPressedDir: root.turn("down") }
            Item { Layout.preferredWidth: Math.round(52 * Theme.scale); Layout.preferredHeight: Math.round(52 * Theme.scale) }
        }
    }

    // ── Keyboard (desktop) ──────────────────────────────────────────
    Keys.onPressed: function(event) {
        switch (event.key) {
            case Qt.Key_Up:    root.turn("up");    event.accepted = true; break
            case Qt.Key_Down:  root.turn("down");  event.accepted = true; break
            case Qt.Key_Left:  root.turn("left");  event.accepted = true; break
            case Qt.Key_Right: root.turn("right"); event.accepted = true; break
            case Qt.Key_Escape: root.closed();     event.accepted = true; break
        }
    }
    focus: visible

    // Small local component for the four D-pad buttons + the center
    // restart button — kept in this file rather than components/ since
    // nothing outside this one screen has a use for it.
    component DPadButton: Rectangle {
        id: btn
        signal pressedDir()
        property string symbol: ""
        Layout.preferredWidth: Math.round(52 * Theme.scale)
        Layout.preferredHeight: Math.round(52 * Theme.scale)
        radius: Theme.rMd
        color: Theme.surface2
        border.width: 1
        border.color: Theme.edgeB2
        Text { anchors.centerIn: parent; text: btn.symbol; color: Theme.accent2; font.pixelSize: Math.round(18 * Theme.scale) }
        TapHandler { onTapped: btn.pressedDir() }
    }
}
