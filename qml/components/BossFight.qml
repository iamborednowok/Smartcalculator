import QtQuick
import QtQuick.Layouts

// Secret boss fight — surfaced from AITab.qml's checkSecretTrigger() same
// as SnakeGame. A green ball wanders the arena; you throw numbers at it
// constrained by a randomly rolled {min, max, operator}, it throws math
// back at you, and both of you can dodge because nothing is a homing/
// instant hit — everything is a projectile that travels and can miss.
//
// Every mechanic below (computeAttackResult, validateAttackInput,
// generateConstraint, launchProjectile/stepProjectile/checkHit,
// stepPlayer, generateQuiz) was written and unit-tested as standalone
// plain JS before any of this QML existed — including full trajectory
// simulations that actually launch a projectile at a stationary target
// (confirms hits work) and at a target that flees perpendicular to the
// shot (confirms dodges work), not just "the collision math looks right
// in isolation". What's here is a direct port of that tested version.
Item {
    id: root
    signal closed()

    // ── Tunables — all the "balance" numbers in one place ─────────────
    readonly property real playerSpeed:      160   // px/s
    readonly property real playerProjSpeed:  260   // px/s
    readonly property real bossProjSpeed:    170   // px/s — slower than the player's throw; typing takes real time/attention the boss doesn't pay
    readonly property real bossWanderSpeed:  70    // px/s
    readonly property real attackCooldownMax: 1.1  // s, between player throws
    readonly property real bossAttackMin:    3.0   // s
    readonly property real bossAttackMax:    5.5   // s
    readonly property real quizSeconds:      10
    readonly property real quizIntervalMin:  12    // s — random gap between quizzes, not tied to boss HP anymore
    readonly property real quizIntervalMax:  20
    readonly property real hitRadius:        22    // px, generous — this is meant to be fair, not a bullet-hell

    // Special abilities — one extra thing Brian can do every 10-16s, on
    // top of (not instead of) his normal periodic math attack.
    readonly property real specialAttackMin: 10
    readonly property real specialAttackMax: 16
    readonly property real gravityDuration:      4
    readonly property real gravityPull:          85   // px/s of pull toward the well — noticeable, not inescapable (playerSpeed is 160)
    readonly property real bossPowerDuration:    8
    readonly property real enlargeDuration:      5
    readonly property real enlargedPlayerRadius: 30   // vs. the normal 16 used in stepPlayer's call below
    readonly property real splitAngleDeg:        18   // degrees each of the two split-shot projectiles diverges from a straight aim
    readonly property real curveAmplitude:       26   // px
    readonly property real curveFrequency:       3.2  // radians/s — how fast the wave oscillates

    // ── Arena + entities ────────────────────────────────────────────
    readonly property real arenaW: arenaArea.width
    readonly property real arenaH: arenaArea.height
    property real playerX: 60
    property real playerY: 60
    property real bossX: 200
    property real bossY: 200
    property real bossTargetX: 200
    property real bossTargetY: 200
    property var heldDirs: ({up:false, down:false, left:false, right:false})

    property real playerHP: 100
    property real bossHP: 100
    property var  playerProjectiles: []   // [{x,y,vx,vy,value}]
    property var  bossProjectiles: []

    property var constraint: ({min:1, max:5, operator:"+"})
    property real attackCooldown: 0
    property var  pendingNum1: null

    property real bossAttackTimer: 4
    property string incomingBossText: ""

    // ── Special ability state ──────────────────────────────────────────
    property real specialAttackTimer: 10
    property bool gravityActive: false
    property real gravityTimer: 0
    property real gravityX: 0
    property real gravityY: 0
    // 1.0 = normal. <1.0 nerfed (good for the player), >1.0 buffed (bad for
    // the player) — scales both bossProjSpeed and the boss's attack value
    // while active. Rolled by rollBossDice(), see triggerSpecialAttack().
    property real bossPowerMultiplier: 1.0
    property real bossPowerTimer: 0
    property bool playerEnlarged: false
    property real enlargeTimer: 0
    property string abilityText: ""

    property string phase: "fight"   // fight | quiz | won | lost
    property var    quiz: null       // {question, answer}
    property real   quizTimeLeft: 0
    property string quizInputText: ""

    property string statusText: ""
    property real   statusTimer: 0

    // Random-moment quiz trigger — replaces the old "at 66% and 33% boss
    // HP" milestones. Counts down only while phase === "fight" (see
    // tick()); when it reaches 0, startQuiz() fires and this gets reset
    // to a fresh random gap for the next one. Since it is purely
    // time-based now, a fight can see anywhere from zero quizzes (a very
    // fast win) to several (a long one) — no longer a fixed count of two.
    property real nextQuizTimer: 0

    function resetGame() {
        playerHP = 100; bossHP = 100
        playerX = Math.max(40, arenaW * 0.15); playerY = arenaH * 0.5
        bossX = arenaW * 0.75; bossY = arenaH * 0.5
        bossTargetX = bossX; bossTargetY = bossY
        heldDirs = {up:false, down:false, left:false, right:false}
        playerProjectiles = []; bossProjectiles = []
        constraint = generateConstraint(Math.random)
        attackCooldown = 0; pendingNum1 = null
        bossAttackTimer = bossAttackMin + Math.random() * (bossAttackMax - bossAttackMin)
        incomingBossText = ""
        specialAttackTimer = specialAttackMin + Math.random() * (specialAttackMax - specialAttackMin)
        gravityActive = false; gravityTimer = 0
        bossPowerMultiplier = 1.0; bossPowerTimer = 0
        playerEnlarged = false; enlargeTimer = 0
        abilityText = ""
        phase = "fight"; quiz = null; quizTimeLeft = 0; quizInputText = ""
        nextQuizTimer = quizIntervalMin + Math.random() * (quizIntervalMax - quizIntervalMin)
        statusText = ""; statusTimer = 0
    }

    function showStatus(text) { statusText = text; statusTimer = 1.6 }

    // ── Pure logic — see file header ───────────────────────────────────
    function computeAttackResult(num1, num2, operator) {
        var raw
        switch (operator) {
            case "+": raw = num1 + num2; break
            case "-": raw = num1 - num2; break
            case "×": raw = num1 * num2; break
            case "÷": raw = num2 === 0 ? 0 : num1 / num2; break
            default:  raw = 0
        }
        return Math.round(raw)
    }

    function validateAttackInput(num1, num2, min, max) {
        return Number.isFinite(num1) && Number.isFinite(num2) &&
               num1 >= min && num1 <= max && num2 >= min && num2 <= max
    }

    function generateConstraint(randomFn) {
        var ops = ["+", "-", "×", "÷"]
        var min = 1 + Math.floor(randomFn() * 4)
        var max = min + 1 + Math.floor(randomFn() * 4)
        var operator = ops[Math.floor(randomFn() * ops.length)]
        return { min: min, max: max, operator: operator }
    }

    function launchProjectile(fromX, fromY, toX, toY, speed, value, curveAmp, curveFreq) {
        curveAmp = curveAmp || 0
        curveFreq = curveFreq || 0
        var dx = toX - fromX, dy = toY - fromY
        var dist = Math.sqrt(dx*dx + dy*dy)
        if (dist === 0) return { x: fromX, y: fromY, vx: 0, vy: -speed, value: value,
                                  curveAmp: curveAmp, curveFreq: curveFreq, elapsed: 0, perpX: 1, perpY: 0 }
        var ux = dx/dist, uy = dy/dist
        // perpX/perpY: unit vector perpendicular to travel direction — the
        // axis a curving shot wobbles along. A 0-amplitude shot never uses
        // it, so this costs nothing for every ordinary attack.
        return { x: fromX, y: fromY, vx: ux*speed, vy: uy*speed, value: value,
                 curveAmp: curveAmp, curveFreq: curveFreq, elapsed: 0, perpX: -uy, perpY: ux }
    }

    function stepProjectile(p, dt) {
        var newElapsed = p.elapsed + dt
        var nx = p.x + p.vx*dt, ny = p.y + p.vy*dt
        if (p.curveAmp) {
            // Delta of a sine wave between this tick and last, applied
            // along the perpendicular axis — not an absolute offset, so a
            // curving shot's own straight-line progress (vx/vy above) is
            // untouched by this and just has a wobble layered on top.
            var prevOff = Math.sin(p.elapsed * p.curveFreq) * p.curveAmp
            var newOff  = Math.sin(newElapsed * p.curveFreq) * p.curveAmp
            var d = newOff - prevOff
            nx += p.perpX * d
            ny += p.perpY * d
        }
        return { x: nx, y: ny, vx: p.vx, vy: p.vy, value: p.value,
                 curveAmp: p.curveAmp, curveFreq: p.curveFreq, elapsed: newElapsed, perpX: p.perpX, perpY: p.perpY }
    }

    function isOutOfBounds(p, w, h) {
        return p.x < -30 || p.x > w + 30 || p.y < -30 || p.y > h + 30   // 30px margin so a shot doesn't visibly vanish right at the wall
    }

    function checkHit(p, targetX, targetY, radius) {
        var dx = p.x - targetX, dy = p.y - targetY
        return (dx*dx + dy*dy) <= radius*radius
    }

    function stepPlayer(pos, held, speed, dt, w, h, radius, gravity) {
        var dx = 0, dy = 0
        if (held.up) dy -= 1
        if (held.down) dy += 1
        if (held.left) dx -= 1
        if (held.right) dx += 1
        if (dx !== 0 && dy !== 0) { var len = Math.sqrt(2); dx /= len; dy /= len }
        var nx = pos.x + dx*speed*dt
        var ny = pos.y + dy*speed*dt
        if (gravity && gravity.active) {
            var gdx = gravity.x - pos.x, gdy = gravity.y - pos.y
            var gdist = Math.sqrt(gdx*gdx + gdy*gdy)
            // gdist>1 guard: right at the well's center the direction is
            // undefined (0/0) and physically meaningless to keep pulling
            // toward — the player has effectively already been pulled in.
            if (gdist > 1) {
                nx += (gdx/gdist) * gravity.pull * dt
                ny += (gdy/gdist) * gravity.pull * dt
            }
        }
        nx = Math.max(radius, Math.min(w - radius, nx))
        ny = Math.max(radius, Math.min(h - radius, ny))
        return { x: nx, y: ny }
    }

    function generateQuiz(randomFn) {
        var ops = ["+", "-", "×"]
        var a = 2 + Math.floor(randomFn() * 10)
        var b = 2 + Math.floor(randomFn() * 10)
        var op = ops[Math.floor(randomFn() * ops.length)]
        var answer
        if (op === "+") answer = a + b
        else if (op === "-") { if (b > a) { var t = a; a = b; b = t } answer = a - b }
        else answer = a * b
        return { question: a + " " + op + " " + b, answer: answer }
    }

    // 1-2 nerfs Brian (good for you), 3-4 does nothing, 5-6 buffs him (bad
    // for you) — see triggerSpecialAttack()'s "dice" case for how the
    // result gets applied.
    function rollBossDice(randomFn) {
        var roll = 1 + Math.floor(randomFn() * 6)
        var multiplier, label
        if (roll <= 2) { multiplier = 0.6; label = "nerfed" }
        else if (roll <= 4) { multiplier = 1.0; label = "neutral" }
        else { multiplier = 1.5; label = "buffed" }
        return { roll: roll, multiplier: multiplier, label: label }
    }

    // ── Player actions ──────────────────────────────────────────────
    function numberTapped(n) {
        if (phase !== "fight" || attackCooldown > 0) return
        if (pendingNum1 === null) { pendingNum1 = n; return }
        throwAttack(pendingNum1, n)
        pendingNum1 = null
    }

    function throwAttack(num1, num2) {
        if (!validateAttackInput(num1, num2, constraint.min, constraint.max)) return
        var value = computeAttackResult(num1, num2, constraint.operator)
        playerProjectiles = playerProjectiles.concat([
            launchProjectile(playerX, playerY, bossX, bossY, playerProjSpeed, value)
        ])
        attackCooldown = attackCooldownMax
        constraint = generateConstraint(Math.random)
    }

    function bossFireAttack() {
        var c = generateConstraint(Math.random)
        var num1 = c.min + Math.floor(Math.random() * (c.max - c.min + 1))
        var num2 = c.min + Math.floor(Math.random() * (c.max - c.min + 1))
        var rawValue = computeAttackResult(num1, num2, c.operator)
        // Only damage scales with a buff/nerf, not projectile speed —
        // dodge timing stays consistent either way; only the consequence
        // of getting hit changes.
        var value = Math.round(rawValue * bossPowerMultiplier)
        incomingBossText = "boss throws: " + num1 + " " + c.operator + " " + num2
        bossProjectiles = bossProjectiles.concat([
            launchProjectile(bossX, bossY, playerX, playerY, bossProjSpeed, value)
        ])
    }

    function pickSpecialAttack(randomFn) {
        var options = ["gravity", "dice", "enlarge", "split", "curve"]
        return options[Math.floor(randomFn() * options.length)]
    }

    // One of Brian's five special abilities, chosen at random — fires on
    // its own timer (specialAttackTimer, see tick()), independent of and
    // in addition to his normal periodic math attack above. Each case
    // sets whatever state that ability needs and a short abilityText,
    // shown via the existing showStatus() flash.
    function triggerSpecialAttack() {
        var kind = pickSpecialAttack(Math.random)
        if (kind === "gravity") {
            gravityActive = true
            gravityTimer = gravityDuration
            gravityX = bossX; gravityY = bossY
            showStatus("🌀 gravity well — get clear!")
        } else if (kind === "dice") {
            var roll = rollBossDice(Math.random)
            bossPowerMultiplier = roll.multiplier
            bossPowerTimer = bossPowerDuration
            showStatus("🎲 Brian rolled a " + roll.roll + " — " + roll.label + "!")
        } else if (kind === "enlarge") {
            playerEnlarged = true
            enlargeTimer = enlargeDuration
            showStatus("📏 enlarged — you're an easier target!")
        } else if (kind === "split") {
            var c = generateConstraint(Math.random)
            var n1 = c.min + Math.floor(Math.random() * (c.max - c.min + 1))
            var n2 = c.min + Math.floor(Math.random() * (c.max - c.min + 1))
            // 0.6x each rather than a full-power duplicate — two shots to
            // dodge instead of one, not simply double the total threat.
            var v = Math.round(computeAttackResult(n1, n2, c.operator) * 0.6 * bossPowerMultiplier)
            var angle = splitAngleDeg * Math.PI / 180
            var dx = playerX - bossX, dy = playerY - bossY
            var dist = Math.sqrt(dx*dx + dy*dy) || 1
            var ux = dx/dist, uy = dy/dist
            var t1 = { x: bossX + (ux*Math.cos(angle) - uy*Math.sin(angle))*dist,
                       y: bossY + (ux*Math.sin(angle) + uy*Math.cos(angle))*dist }
            var t2 = { x: bossX + (ux*Math.cos(-angle) - uy*Math.sin(-angle))*dist,
                       y: bossY + (ux*Math.sin(-angle) + uy*Math.cos(-angle))*dist }
            bossProjectiles = bossProjectiles.concat([
                launchProjectile(bossX, bossY, t1.x, t1.y, bossProjSpeed, v),
                launchProjectile(bossX, bossY, t2.x, t2.y, bossProjSpeed, v)
            ])
            showStatus("⚡ binary split shot — two incoming!")
        } else if (kind === "curve") {
            var c2 = generateConstraint(Math.random)
            var n1b = c2.min + Math.floor(Math.random() * (c2.max - c2.min + 1))
            var n2b = c2.min + Math.floor(Math.random() * (c2.max - c2.min + 1))
            var vb = Math.round(computeAttackResult(n1b, n2b, c2.operator) * bossPowerMultiplier)
            bossProjectiles = bossProjectiles.concat([
                launchProjectile(bossX, bossY, playerX, playerY, bossProjSpeed, vb, curveAmplitude, curveFrequency)
            ])
            showStatus("📈 curve shot incoming — it won't fly straight")
        }
    }

    function submitQuizAnswer() {
        if (phase !== "quiz" || !quiz) return
        var val = parseInt(quizInputText, 10)
        if (val === quiz.answer) {
            phase = "fight"; quiz = null; quizInputText = ""
            showStatus("solved it — back to the fight")
        } else {
            quizInputText = ""   // wrong: clear and let them try again before the clock runs out
        }
    }

    function checkQuizTimer(dt) {
        nextQuizTimer -= dt
        if (nextQuizTimer <= 0) {
            startQuiz()
            nextQuizTimer = quizIntervalMin + Math.random() * (quizIntervalMax - quizIntervalMin)
        }
    }

    function startQuiz() {
        phase = "quiz"
        quiz = generateQuiz(Math.random)
        quizTimeLeft = quizSeconds
        quizInputText = ""
    }

    // ── Main tick ────────────────────────────────────────────────────
    function tick(dt) {
        if (statusTimer > 0) statusTimer -= dt

        if (phase === "quiz") {
            quizTimeLeft -= dt
            if (quizTimeLeft <= 0) { phase = "lost" }
            return
        }
        if (phase !== "fight") return

        // boss wander: pick a new random target once close to the current one
        var toTargetX = bossTargetX - bossX, toTargetY = bossTargetY - bossY
        if (Math.sqrt(toTargetX*toTargetX + toTargetY*toTargetY) < 12) {
            bossTargetX = 30 + Math.random() * Math.max(1, arenaW - 60)
            bossTargetY = 30 + Math.random() * Math.max(1, arenaH - 60)
        } else {
            var moved = launchProjectile(bossX, bossY, bossTargetX, bossTargetY, bossWanderSpeed, 0)
            bossX += moved.vx * dt; bossY += moved.vy * dt
        }

        var pl = stepPlayer({x: playerX, y: playerY}, heldDirs, playerSpeed, dt, arenaW, arenaH, 16,
                             {active: gravityActive, x: gravityX, y: gravityY, pull: gravityPull})
        playerX = pl.x; playerY = pl.y

        if (attackCooldown > 0) attackCooldown = Math.max(0, attackCooldown - dt)

        // ── Ability timers — each just counts down and turns itself off;
        // triggerSpecialAttack() is the only place that turns one on ──
        if (gravityActive) { gravityTimer -= dt; if (gravityTimer <= 0) gravityActive = false }
        if (bossPowerTimer > 0) { bossPowerTimer -= dt; if (bossPowerTimer <= 0) bossPowerMultiplier = 1.0 }
        if (playerEnlarged) { enlargeTimer -= dt; if (enlargeTimer <= 0) playerEnlarged = false }

        specialAttackTimer -= dt
        if (specialAttackTimer <= 0) {
            triggerSpecialAttack()
            specialAttackTimer = specialAttackMin + Math.random() * (specialAttackMax - specialAttackMin)
        }

        bossAttackTimer -= dt
        if (bossAttackTimer <= 0) {
            bossFireAttack()
            bossAttackTimer = bossAttackMin + Math.random() * (bossAttackMax - bossAttackMin)
        }

        // advance + resolve player projectiles against the boss
        var survivingPlayer = []
        for (var i = 0; i < playerProjectiles.length; i++) {
            var pp = stepProjectile(playerProjectiles[i], dt)
            if (checkHit(pp, bossX, bossY, hitRadius)) {
                bossHP = Math.max(0, Math.min(100, bossHP - pp.value))
                showStatus(pp.value >= 0 ? ("hit! " + pp.value + " damage") : ("that healed the boss " + (-pp.value) + " — oops"))
            } else if (!isOutOfBounds(pp, arenaW, arenaH)) {
                survivingPlayer.push(pp)
            }
        }
        playerProjectiles = survivingPlayer

        // advance + resolve boss projectiles against the player — hit
        // radius grows while playerEnlarged is active (see triggerSpecialAttack's "enlarge" case)
        var survivingBoss = []
        var effectiveRadius = playerEnlarged ? enlargedPlayerRadius : hitRadius
        for (var j = 0; j < bossProjectiles.length; j++) {
            var bp = stepProjectile(bossProjectiles[j], dt)
            if (checkHit(bp, playerX, playerY, effectiveRadius)) {
                playerHP = Math.max(0, Math.min(100, playerHP - bp.value))
                showStatus(bp.value >= 0 ? ("boss hit you for " + bp.value) : ("healed " + (-bp.value) + " HP"))
            } else if (!isOutOfBounds(bp, arenaW, arenaH)) {
                survivingBoss.push(bp)
            }
        }
        bossProjectiles = survivingBoss

        checkQuizTimer(dt)
        if (bossHP <= 0) phase = "won"
        else if (playerHP <= 0) phase = "lost"
    }

    Timer {
        interval: 33
        running: root.visible && (root.phase === "fight" || root.phase === "quiz")
        repeat: true
        onTriggered: root.tick(0.033)
    }
    Component.onCompleted: resetGame()
    onVisibleChanged: if (visible) resetGame()

    // ── Rendering ────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: Theme.bg }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sp3
        spacing: Theme.sp2

        RowLayout {
            Layout.fillWidth: true
            Text { text: "👹 secret boss fight"; color: Theme.text; font.family: Theme.fontSans; font.weight: Font.DemiBold; font.pixelSize: Math.round(15 * Theme.scale) }
            Item { Layout.fillWidth: true }
            Text {
                text: "close"; color: Theme.accent; font.family: Theme.fontSans; font.weight: Font.Medium; font.pixelSize: Math.round(12 * Theme.scale)
                TapHandler { onTapped: root.closed() }
            }
        }

        // ── HP bars ──────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp3
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: "boss"; color: Theme.gradB; font.family: Theme.fontMono; font.pixelSize: Math.round(10 * Theme.scale) }
                Rectangle {
                    Layout.fillWidth: true; height: Math.round(10 * Theme.scale); radius: height/2; color: Theme.surface2
                    Rectangle { width: parent.width * (root.bossHP/100); height: parent.height; radius: height/2; color: Theme.gradB
                        Behavior on width { NumberAnimation { duration: 150 } } }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: "you"; color: Theme.accent2; font.family: Theme.fontMono; font.pixelSize: Math.round(10 * Theme.scale) }
                Rectangle {
                    Layout.fillWidth: true; height: Math.round(10 * Theme.scale); radius: height/2; color: Theme.surface2
                    Rectangle { width: parent.width * (root.playerHP/100); height: parent.height; radius: height/2; color: Theme.accent2
                        Behavior on width { NumberAnimation { duration: 150 } } }
                }
            }
        }

        // ── Arena ────────────────────────────────────────────────────
        Item {
            id: arenaArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                color: Theme.surface
                radius: Theme.rMd
                border.width: 1
                border.color: Theme.edgeB2
                clip: true

                // gravity well — rendered under the boss/player so it reads as a floor effect, not an obstacle
                Rectangle {
                    visible: root.gravityActive
                    x: root.gravityX - width/2; y: root.gravityY - height/2
                    width: Math.round(70 * Theme.scale); height: width; radius: width/2
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.accent
                    opacity: 0.6
                }
                // boss — border tints while a dice buff/nerf is active, so
                // the effect reads as belonging to the boss rather than
                // just the abilityText line at the bottom
                Rectangle {
                    x: root.bossX - width/2; y: root.bossY - height/2
                    width: Math.round(34 * Theme.scale); height: width; radius: width/2
                    color: Theme.gradB
                    border.width: root.bossPowerMultiplier !== 1.0 ? 3 : 0
                    border.color: root.bossPowerMultiplier > 1.0 ? Theme.accent : Theme.accent2
                    visible: root.phase === "fight" || root.phase === "quiz"
                }
                // player — grows while enlarged (see triggerSpecialAttack's "enlarge" case)
                Rectangle {
                    property real size: (root.playerEnlarged ? root.enlargedPlayerRadius : 12) * 2 * Theme.scale
                    x: root.playerX - size/2; y: root.playerY - size/2
                    width: size; height: size; radius: size/2
                    color: Theme.accent2
                    visible: root.phase === "fight" || root.phase === "quiz"
                    Behavior on size { NumberAnimation { duration: 200 } }
                }
                // player projectiles
                Repeater {
                    model: root.playerProjectiles
                    delegate: Rectangle {
                        x: modelData.x - 5; y: modelData.y - 5; width: 10; height: 10; radius: 5
                        color: modelData.value >= 0 ? Theme.accent2 : Theme.gradC
                    }
                }
                // boss projectiles
                Repeater {
                    model: root.bossProjectiles
                    delegate: Rectangle {
                        x: modelData.x - 5; y: modelData.y - 5; width: 10; height: 10; radius: 5
                        color: modelData.value >= 0 ? Theme.accent : Theme.gradC
                    }
                }

                // status flash
                Text {
                    anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: Theme.sp2
                    visible: root.statusTimer > 0
                    text: root.statusText
                    color: Theme.text; font.family: Theme.fontSans; font.weight: Font.Medium; font.pixelSize: Math.round(12 * Theme.scale)
                }

                // quiz overlay
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0,0,0,0.65)
                    visible: root.phase === "quiz"
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.sp2
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "solve it or die"; color: Theme.accent; font.family: Theme.fontSans; font.weight: Font.Bold; font.pixelSize: Math.round(14 * Theme.scale) }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.quiz ? root.quiz.question + " = ?" : ""; color: "#FFFFFF"; font.family: Theme.fontMono; font.pixelSize: Math.round(24 * Theme.scale) }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.ceil(Math.max(0, root.quizTimeLeft)) + "s"; color: root.quizTimeLeft < 3 ? Theme.accent : "#CCCCCC"; font.family: Theme.fontMono; font.pixelSize: Math.round(13 * Theme.scale) }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.round(120 * Theme.scale); height: Math.round(40 * Theme.scale); radius: Theme.rMd
                            color: Theme.surface
                            Text { anchors.centerIn: parent; text: root.quizInputText.length ? root.quizInputText : "0"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Math.round(16 * Theme.scale) }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Theme.sp1
                            Repeater {
                                model: ["1","2","3","4","5","6","7","8","9","←","0","OK"]
                                delegate: Rectangle {
                                    width: Math.round(34 * Theme.scale); height: Math.round(34 * Theme.scale); radius: Theme.rSm
                                    color: Theme.surface2
                                    Text { anchors.centerIn: parent; text: modelData; color: Theme.accent2; font.pixelSize: Math.round(13 * Theme.scale) }
                                    TapHandler {
                                        onTapped: {
                                            if (modelData === "←") root.quizInputText = root.quizInputText.slice(0, -1)
                                            else if (modelData === "OK") root.submitQuizAnswer()
                                            else if (root.quizInputText.length < 4) root.quizInputText += modelData
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // win / lose overlay
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0,0,0,0.6)
                    visible: root.phase === "won" || root.phase === "lost"
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.sp2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.phase === "won" ? "boss defeated 🏆" : "you died 💀"
                            color: root.phase === "won" ? Theme.gradB : Theme.accent
                            font.family: Theme.fontSans; font.weight: Font.Bold; font.pixelSize: Math.round(18 * Theme.scale)
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "tap to try again"; color: "#CCCCCC"; font.family: Theme.fontSans; font.pixelSize: Math.round(11 * Theme.scale) }
                    }
                    TapHandler { onTapped: root.resetGame() }
                }
            }
        }

        // ── Attack constraint + number picker ───────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.sp1
            visible: root.phase === "fight"
            Text {
                text: root.attackCooldown > 0
                    ? ("reloading… " + root.attackCooldown.toFixed(1) + "s")
                    : ("use " + root.constraint.operator + "  ·  pick two numbers " + root.constraint.min + "–" + root.constraint.max
                       + (root.pendingNum1 !== null ? ("  ·  first: " + root.pendingNum1) : "")
                       + (root.incomingBossText ? ("   |   " + root.incomingBossText) : ""))
                color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(11 * Theme.scale)
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.sp2
                visible: root.attackCooldown <= 0
                Repeater {
                    model: root.constraint.max - root.constraint.min + 1
                    delegate: Rectangle {
                        property int n: root.constraint.min + index
                        width: Math.round(40 * Theme.scale); height: Math.round(40 * Theme.scale); radius: Theme.rMd
                        color: root.pendingNum1 === n ? Theme.accent2 : Theme.surface2
                        border.width: 1; border.color: Theme.edgeB2
                        Text { anchors.centerIn: parent; text: parent.n; color: root.pendingNum1 === parent.n ? Theme.textOnAccent : Theme.text; font.family: Theme.fontMono; font.pixelSize: Math.round(15 * Theme.scale) }
                        TapHandler { onTapped: root.numberTapped(parent.n) }
                    }
                }
            }
        }

        // ── D-pad (dodge movement) ──────────────────────────────────
        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            rowSpacing: Theme.sp1
            columnSpacing: Theme.sp1
            visible: root.phase === "fight"

            Item { Layout.preferredWidth: Math.round(44 * Theme.scale); Layout.preferredHeight: Math.round(44 * Theme.scale) }
            HoldButton { symbol: "▲"; onHeldChanged: root.heldDirs = Object.assign({}, root.heldDirs, {up: held}) }
            Item { Layout.preferredWidth: Math.round(44 * Theme.scale); Layout.preferredHeight: Math.round(44 * Theme.scale) }

            HoldButton { symbol: "◀"; onHeldChanged: root.heldDirs = Object.assign({}, root.heldDirs, {left: held}) }
            Item { Layout.preferredWidth: Math.round(44 * Theme.scale); Layout.preferredHeight: Math.round(44 * Theme.scale) }
            HoldButton { symbol: "▶"; onHeldChanged: root.heldDirs = Object.assign({}, root.heldDirs, {right: held}) }

            Item { Layout.preferredWidth: Math.round(44 * Theme.scale); Layout.preferredHeight: Math.round(44 * Theme.scale) }
            HoldButton { symbol: "▼"; onHeldChanged: root.heldDirs = Object.assign({}, root.heldDirs, {down: held}) }
            Item { Layout.preferredWidth: Math.round(44 * Theme.scale); Layout.preferredHeight: Math.round(44 * Theme.scale) }
        }
    }

    Keys.onPressed: function(event) {
        switch (event.key) {
            case Qt.Key_Up:    heldDirs = Object.assign({}, heldDirs, {up: true});    event.accepted = true; break
            case Qt.Key_Down:  heldDirs = Object.assign({}, heldDirs, {down: true});  event.accepted = true; break
            case Qt.Key_Left:  heldDirs = Object.assign({}, heldDirs, {left: true});  event.accepted = true; break
            case Qt.Key_Right: heldDirs = Object.assign({}, heldDirs, {right: true}); event.accepted = true; break
            case Qt.Key_Escape: root.closed(); event.accepted = true; break
        }
    }
    Keys.onReleased: function(event) {
        switch (event.key) {
            case Qt.Key_Up:    heldDirs = Object.assign({}, heldDirs, {up: false});    event.accepted = true; break
            case Qt.Key_Down:  heldDirs = Object.assign({}, heldDirs, {down: false});  event.accepted = true; break
            case Qt.Key_Left:  heldDirs = Object.assign({}, heldDirs, {left: false});  event.accepted = true; break
            case Qt.Key_Right: heldDirs = Object.assign({}, heldDirs, {right: false}); event.accepted = true; break
        }
    }
    focus: visible

    // Press-and-hold D-pad button — unlike Snake's DPadButton (a single
    // tap = one turn), dodge movement needs to know whether a direction
    // is CURRENTLY held down, not just that it was tapped once. Exposes
    // `held` (bool) + onHeldChanged rather than a tap signal.
    component HoldButton: Rectangle {
        id: hbtn
        property string symbol: ""
        // property bool already auto-generates a heldChanged() signal —
        // declaring one explicitly here would collide with it rather than
        // add anything. Setting `held` below is all onHeldChanged callers
        // (the D-pad usages above) need.
        property bool held: false
        Layout.preferredWidth: Math.round(44 * Theme.scale)
        Layout.preferredHeight: Math.round(44 * Theme.scale)
        radius: Theme.rMd
        color: held ? Theme.surfaceOp : Theme.surface2
        border.width: 1
        border.color: Theme.edgeB2
        Text { anchors.centerIn: parent; text: hbtn.symbol; color: Theme.accent2; font.pixelSize: Math.round(16 * Theme.scale) }
        TapHandler {
            onPressedChanged: hbtn.held = pressed
        }
    }
}
