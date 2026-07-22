import QtQuick
import QtQuick.Layouts
import Qt.labs.settings 1.0
import SmartCalc.Backend 1.0
import "components"

Item {
    id: root
    property var window: ApplicationWindow.window

    // ── Entrance animation (plays each time this tab becomes current) ──
    // A quick fade + gentle pop-in on switching to this tab instead of
    // just snapping into view — see Theme.popDuration/popEasing.
    opacity: 1.0
    scale: 1.0
    // Driven from Main.qml — see GraphTab.qml for why this is no longer
    // StackLayout.isCurrentItem (this tab is now lazy-loaded via Loader).
    property bool isCurrentTab: false
    onIsCurrentTabChanged: if (isCurrentTab) { enterFade.restart(); enterScale.restart() }
    NumberAnimation { id: enterFade;  target: root; property: "opacity"; from: 0.0;  to: 1.0; duration: Theme.popDuration; easing.type: Easing.OutQuad }
    NumberAnimation { id: enterScale; target: root; property: "scale";   from: 0.97; to: 1.0; duration: Theme.popDuration; easing.type: Theme.popEasing; easing.overshoot: Theme.popOvershoot }

    // ── Mode switcher ────────────────────────────────────────────────
    readonly property var modes: [
        { label:"Dice",  value:"dice"  }, { label:"Coin",  value:"coin"  },
        { label:"Range", value:"range" }, { label:"Quiz",  value:"quiz"  },
    ]
    property string mode: "dice"

    // ── Dice state ───────────────────────────────────────────────────
    property int diceType:    6
    property int diceCount:   1
    property var diceResults: []
    readonly property var diceTypes: [4,6,8,10,12,20,100]

    function rollDice() {
        var rolls = []
        for (var i = 0; i < diceCount; i++) rolls.push(Math.floor(Math.random()*diceType)+1)
        diceResults = rolls
    }

    // ── Coin state ───────────────────────────────────────────────────
    property var  coinResult:   null   // null | "H" | "T"
    onCoinResultChanged: if (coinResult !== null) coinLandAnim.restart()
    property bool coinFlipping: false
    property var  coinHistory:  []

    Timer {
        id: coinTimer
        interval: 400
        onTriggered: {
            var r = Math.random() < 0.5 ? "H" : "T"
            root.coinResult   = r
            root.coinHistory  = [r].concat(root.coinHistory.slice(0,49))
            root.coinFlipping = false
        }
    }
    function flipCoin() { if (!coinFlipping) { coinFlipping = true; coinTimer.restart() } }

    // ── Range state ──────────────────────────────────────────────────
    property string randMin: "1"
    property string randMax: "100"
    property var    randResult: null

    function pickRandom() {
        var mn = parseInt(randMin), mx = parseInt(randMax)
        if (isNaN(mn) || isNaN(mx) || mn >= mx) return
        randResult = Math.floor(Math.random()*(mx-mn+1))+mn
    }

    // ── Math quiz state ──────────────────────────────────────────────
    property var    currentProb: null
    property string mathAnswer:  ""
    property var    mathChecked: null
    // mathScore is scoped to the current session now — it zeroes whenever
    // a new session starts (startNewSession(), via Start or Play Again)
    // rather than free-running until "reset" is tapped. In Endless mode
    // that's the same accumulate-until-reset behavior as before, since a
    // session with no length target never auto-completes.
    property var    mathScore:   ({right:0, wrong:0})
    property int    streak:      0
    property string difficulty:  "Easy"
    property bool   showHint:    false
    property string currentTag:  ""
    // QOL: last couple of "tag|level" keys used, most recent first — lets
    // newMathProblem() avoid picking the same problem type twice in a row
    // (or twice within 2 questions). See newMathProblem() below.
    property var    recentGens:  []

    // "Word Problems" is appended after Impossible rather than slotted in
    // between the difficulty rungs — it's a different axis (reading
    // comprehension vs. raw arithmetic difficulty), not another step up
    // the Easy→Impossible ladder, so it shouldn't visually interrupt that
    // escalating color sequence.
    readonly property var difficulties: ["Random","Easy","Hard","Nightmare","Impossible","Word Problems"]
    readonly property var diffIcons: ({ "Random":"🎲", "Easy":"🟢", "Hard":"🟠", "Nightmare":"🔴", "Impossible":"💀", "Word Problems":"📖" })

    // ── Quiz session mode ("better quiz" pass) ─────────────────────────
    // A session is either a fixed length (score resets, ends with a
    // summary card) or "∞" (the original endless behavior, unchanged).
    property string quizLength: "10"
    readonly property var quizLengths: [
        { label: "10 Qs",  value: "10" },
        { label: "20 Qs",  value: "20" },
        { label: "Endless", value: "∞" },
    ]
    property int    sessionBestStreak:  0
    property var    sessionTimes:       []     // seconds per answered question, this session
    property real   questionStartedAt:  0      // Date.now() when the current problem was shown
    property bool   newBestThisSession: false
    property bool   showSummary:        false

    readonly property bool sessionComplete: quizLength !== "∞"
        && (mathScore.right + mathScore.wrong) >= parseInt(quizLength)

    // Small standalone persisted store, same pattern AITab.qml uses for
    // aiPrefs — a couple of ints don't need the full AppSettings/QSettings
    // C++ round trip.
    Settings {
        id: quizStats
        category: "RandomTabQuizStatsV1"
        property int bestStreak:    0
        property int lifetimeRight: 0
        property int lifetimeWrong: 0
    }

    function startNewSession() {
        mathScore          = { right: 0, wrong: 0 }
        streak             = 0
        sessionBestStreak  = 0
        sessionTimes       = []
        recentGens         = []
        newBestThisSession = false
        showSummary        = false
        newMathProblem()
    }

    function finishSession() { showSummary = true }
    function backToSettings() { showSummary = false; currentProb = null; mathChecked = null }

    function avgSessionTime() {
        if (sessionTimes.length === 0) return 0
        var sum = 0
        for (var i = 0; i < sessionTimes.length; i++) sum += sessionTimes[i]
        return sum / sessionTimes.length
    }

    function rn(range, min) { return Math.floor(Math.random() * range) + (min || 1) }
    function ri(n) { return Math.floor(Math.random() * n) }
    function fix(n, d) { return parseFloat(n.toFixed(d !== undefined ? d : 4)) }
    // Added for the new GCD/LCM/Combinations problem types below.
    function gcdOf(a, b) { while (b) { var t = b; b = a % b; a = t } return a }
    function factorial(n) { var r = 1; for (var i = 2; i <= n; i++) r *= i; return r }
    function nCr(n, r) { return Math.round(factorial(n) / (factorial(r) * factorial(n - r))) }
    // Added for the new Word Problems pool below — a small rotating cast of
    // names so problems read like real scenarios instead of "Person A/B".
    readonly property var wordProblemNames: ["Maya","Liam","Priya","Noah","Aisha","Diego","Emma","Kenji","Sofia","Omar"]
    function pickName() { return wordProblemNames[ri(wordProblemNames.length)] }

    // PERF FIX: this used to be a plain function called from
    // newMathProblem(), so all ~29 pool entries (and their `gen` closures)
    // were reconstructed from scratch on every single question — real
    // garbage-collector pressure on a rapid-fire quiz session, for data
    // that never actually changes. It's a `readonly property var` now,
    // so the array literal below is built exactly once (same pattern as
    // FormulaTab.qml's `formulaData`), and newMathProblem() just reads
    // `problemPool` instead of calling this every time.
    readonly property var problemPool: buildProblemPool()

    function buildProblemPool() {
        return [
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
            { tag:"Doubling",       level:"Easy",       gen: function() {
                if (Math.random() < 0.5) { var n=rn(50,1)*2; return {q:"Half of "+n, a:n/2} }
                var n=rn(50,1); return {q:"Double "+n, a:n*2}
            }},
            { tag:"Comparing",      level:"Easy",       gen: function() { var a=rn(90,10),b=rn(90,10); while(b===a) b=rn(90,10); return {q:"Which is bigger: "+a+" or "+b+"? (type the larger number)", a:Math.max(a,b), hint:"Compare digit by digit, starting from the left"} }},
            { tag:"Money",          level:"Easy",       gen: function() { var a=rn(4000,100)/100,b=rn(4000,100)/100; return {q:"$"+a.toFixed(2)+" + $"+b.toFixed(2), a:fix(a+b,2), hint:"Add the dollars, then add the cents"} }},

            { tag:"Addition",       level:"Hard",       gen: function() { var a=rn(9000,1000),b=rn(9000,1000); return {q:a+" + "+b, a:a+b} }},
            { tag:"Multiplication", level:"Hard",       gen: function() { var a=rn(50,10),b=rn(20,5); return {q:a+" × "+b, a:a*b} }},
            { tag:"BODMAS",         level:"Hard",       gen: function() { var a=rn(10,2),b=rn(8,2),c=rn(6,2),d=rn(4,1); return {q:a+" × "+b+" + "+c+" × "+d, a:a*b+c*d, hint:"Multiply first, then add"} }},
            { tag:"Squares",        level:"Hard",       gen: function() { var n=rn(25,10); return {q:n+"²", a:n*n} }},
            { tag:"Algebra",        level:"Hard",       gen: function() { var x=rn(15,1),m=rn(5,2),c=rn(10,0); return {q:m+"x + "+c+" = "+(m*x+c)+"  →  x = ?", a:x, hint:"Subtract "+c+", then divide by "+m} }},
            { tag:"% Change",       level:"Hard",       gen: function() { var a=rn(80,20),p=[10,15,20,25,30][ri(5)],up=Math.random()<0.5; var r=up ? a*(1+p/100) : a*(1-p/100); return {q:(up?"Increase ":"Decrease ")+a+" by "+p+"%", a:fix(r,2)} }},
            { tag:"Decimals",       level:"Hard",       gen: function() { var a=rn(9,1)+ri(9)/10,b=rn(9,1)+ri(9)/10; return {q:fix(a,1)+" × "+fix(b,1), a:fix(a*b,2)} }},
            { tag:"Missing No.",    level:"Hard",       gen: function() { var a=rn(20,5),b=rn(10,2),c=a*b; return {q:a+" × __ = "+c, a:b, hint:"What times "+a+" = "+c+"?"} }},
            { tag:"Average",        level:"Hard",       gen: function() { var target=rn(30,20),d1=rn(9,1)-4,d2=rn(9,1)-4,d3=-(d1+d2); var a=target+d1,b=target+d2,c=target+d3,d=target; return {q:"Average of "+a+", "+b+", "+c+", "+d, a:target, hint:"Add all four numbers, then divide by 4"} }},
            { tag:"Ratios",         level:"Hard",       gen: function() { var r1=rn(5,2),r2=rn(5,2); while(r2===r1) r2=rn(5,2); var mult=rn(8,2),given=r1*mult; return {q:"Ratio "+r1+":"+r2+" — if the first amount is "+given+", what's the second?", a:r2*mult, hint:"Find the multiplier ("+given+" ÷ "+r1+"), then × "+r2} }},
            { tag:"Simple Interest",level:"Hard",       gen: function() { var p=rn(20,2)*100,r=[2,3,4,5,6,8,10][ri(7)],t=rn(5,2); return {q:"Simple interest on $"+p+" at "+r+"% for "+t+" years", a:fix(p*r*t/100,2), hint:"Interest = Principal × Rate × Time ÷ 100"} }},

            { tag:"Multiplication", level:"Nightmare",  gen: function() { var a=rn(900,100),b=rn(90,10); return {q:a+" × "+b, a:a*b} }},
            { tag:"BODMAS",         level:"Nightmare",  gen: function() { var a=rn(20,5),b=rn(15,3),c=rn(10,2),d=rn(8,2); return {q:"("+a+" + "+b+") × ("+c+" − "+d+")", a:(a+b)*(c-d), hint:"Solve each bracket first"} }},
            { tag:"Fractions",      level:"Nightmare",  gen: function() { var a=rn(8,2),b=rn(8,2),c=rn(8,2),d=rn(8,2); return {q:a+"/"+b+" + "+c+"/"+d, a:fix((a*d+b*c)/(b*d)), hint:"Common denominator is "+b*d} }},
            { tag:"Cube Root",      level:"Nightmare",  gen: function() { var n=[2,3,4,5,6,7,8,9,10][ri(9)]; return {q:"∛"+(n*n*n), a:n} }},
            { tag:"Geometric Seq.", level:"Nightmare",  gen: function() { var a=rn(5,1),r=rn(4,2),n=rn(4,3); var s=a*(Math.pow(r,n)-1)/(r-1); return {q:"Geo sum: "+a+"+"+a*r+"+"+a*r*r+"+ … ("+n+" terms)", a:fix(s,2), hint:"S = a(rⁿ−1)/(r−1)"} }},
            { tag:"Quadratic",      level:"Nightmare",  gen: function() { var x1=rn(8,1),x2=rn(6,1); var b=-(x1+x2),c=x1*x2; var bs=(b>=0?"+":"")+b,cs=(c>=0?"+":"")+c; return {q:"x²"+bs+"x"+cs+"=0  larger x=?", a:Math.max(x1,x2), hint:"Find two numbers that multiply to "+c+" and add to "+b} }},
            { tag:"Simultaneous",   level:"Nightmare",  gen: function() { var x=rn(8,1),y=rn(8,1),a=rn(4,2),b=rn(4,2); var s=a*x+b*y,d=x-y; return {q:a+"x + "+b+"y = "+s+",  x − y = "+d+"  →  x = ?", a:x, hint:"Substitute x = y + "+d} }},
            { tag:"GCD",            level:"Nightmare",  gen: function() { var g=rn(8,2),m1=rn(6,2),m2=rn(6,2); while(m2===m1) m2=rn(6,2); var a=g*m1,b=g*m2; return {q:"GCD of "+a+" and "+b, a:gcdOf(a,b), hint:"List the factors of each, or use repeated division"} }},
            { tag:"LCM",            level:"Nightmare",  gen: function() { var a=rn(10,3),b=rn(10,3); while(b===a) b=rn(10,3); return {q:"LCM of "+a+" and "+b, a:(a*b)/gcdOf(a,b), hint:"LCM × GCD = "+a+" × "+b} }},
            { tag:"Speed",          level:"Nightmare",  gen: function() {
                var speed=rn(12,4)*10, time=rn(6,2), dist=speed*time
                if (Math.random() < 0.5) return {q:"Traveling at "+speed+" km/h for "+time+" hours, how far (km)?", a:dist, hint:"distance = speed × time"}
                return {q:"Traveling "+dist+" km at "+speed+" km/h, how many hours?", a:time, hint:"time = distance ÷ speed"}
            }},

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
            { tag:"Combinations",   level:"Impossible", gen: function() { var n=rn(6,5),r=rn(n-2,2); return {q:n+" choose "+r+"  (ⁿCᵣ)", a:nCr(n,r), hint:"nCr = n! / (r!(n−r)!)"} }},
            { tag:"Complex Magnitude", level:"Impossible", gen: function() {
                var triples=[[3,4,5],[6,8,10],[5,12,13],[8,15,17],[7,24,25],[9,12,15],[20,21,29]]
                var t=triples[ri(triples.length)]
                var re=(Math.random()<0.5?"−":"")+t[0]
                var im=(Math.random()<0.5?" − ":" + ")+t[1]+"i"
                return {q:"|"+re+im+"|", a:t[2], hint:"|a + bi| = √(a² + b²)"}
            }},
            { tag:"Matrix Trace",   level:"Impossible", gen: function() { var a=rn(9,1),b=rn(9,1),c=rn(9,1),d=rn(9,1); return {q:"|"+a+" "+b+"|\n|"+c+" "+d+"|  →  trace=?", a:a+d, hint:"trace = sum of the main diagonal (top-left, bottom-right)"} }},

            // ── Word Problems (this request) ──────────────────────────
            // Unlike every generator above, the operation isn't spelled
            // out in the question ("×", "÷", "GCD of…") — it only becomes
            // clear once the 1-3 sentences are actually read. Same rule as
            // GCD/LCM above: `a` is always computed from the numbers
            // actually shown in `q`, never backfilled from a construction
            // target, so correctness doesn't depend on the setup math
            // being airtight.
            { tag:"Shopping Change", level:"Word Problems", gen: function() {
                var n1=rn(4,2), p1=fix(rn(350,150)/100,2), n2=rn(5,2), p2=fix(rn(200,50)/100,2)
                var cost=fix(n1*p1+n2*p2,2)
                var bill=Math.ceil(cost/5)*5 + 5*(ri(2)+1)   // always ≥5 above cost
                var name=pickName()
                return {
                    q:name+" buys "+n1+" notebooks at $"+p1.toFixed(2)+" each and "+n2+" pens at $"+p2.toFixed(2)+" each. They pay with a $"+bill+" bill. How much change should they get back?",
                    a:fix(bill-cost,2),
                    hint:"Find the total cost first, then subtract it from the bill."
                }
            }},
            { tag:"Splitting a Bill", level:"Word Problems", gen: function() {
                var n=rn(5,3)
                var per=fix(rn(25,8) + [0,0.25,0.5,0.75][ri(4)], 2)
                var total=fix(per*n,2)
                return {
                    q:n+" friends split a $"+total.toFixed(2)+" restaurant bill equally. How much does each person pay?",
                    a:fix(total/n,2),
                    hint:"Divide the total by the number of friends."
                }
            }},
            { tag:"Leftovers", level:"Word Problems", gen: function() {
                var box=rn(7,4), full=rn(9,3), rem=ri(box)
                var total=box*full+rem
                return {
                    q:"A bakery makes "+total+" muffins. They pack them into boxes of "+box+". After filling as many full boxes as possible, how many muffins are left over?",
                    a: total % box,
                    hint:"Divide the total by the box size — the remainder is what's left over."
                }
            }},
            { tag:"Rate Over Time", level:"Word Problems", gen: function() {
                var rate=rn(20,5), time=rn(12,3)
                return {
                    q:"A printer prints "+rate+" pages per minute. How many pages does it print in "+time+" minutes?",
                    a:rate*time,
                    hint:"Multiply the rate by the time."
                }
            }},
            { tag:"More Than", level:"Word Problems", gen: function() {
                var amt=rn(40,10), diff=rn(20,5)
                var n1=pickName(), n2=pickName()
                while (n2===n1) n2=pickName()
                return {
                    q:n1+" has "+amt+" trading cards. "+n2+" has "+diff+" more cards than "+n1+". How many cards does "+n2+" have?",
                    a:amt+diff,
                    hint:"'More than' means you add the extra amount."
                }
            }},
            { tag:"Fraction of a Group", level:"Word Problems", gen: function() {
                var denoms=[2,3,4,5,10], d=denoms[ri(denoms.length)]
                var nlist=[]; for (var k=1;k<d;k++) nlist.push(k)
                var num=nlist[ri(nlist.length)]
                var total=d*rn(9,2)
                var part=total*num/d
                return {
                    q:"A classroom has "+total+" students. "+num+"/"+d+" of them are wearing red shirts. How many students are NOT wearing red shirts?",
                    a: total-part,
                    hint:"Find how many wear red first, then subtract from the total."
                }
            }},
            { tag:"Age", level:"Word Problems", gen: function() {
                var age=rn(50,8), years=rn(15,2), name=pickName()
                if (Math.random() < 0.5) {
                    return {
                        q:name+" is "+age+" years old today. How old will "+name+" be in "+years+" years?",
                        a:age+years,
                        hint:"Add the years to the current age."
                    }
                }
                var y=Math.min(years, age-1)   // clamp so "years ago" can't go before birth
                return {
                    q:name+" is "+age+" years old today. How old was "+name+" "+y+" years ago?",
                    a:age-y,
                    hint:"Subtract the years from the current age."
                }
            }},
            { tag:"Trip Remaining", level:"Word Problems", gen: function() {
                var legA=rn(200,80), legB=rn(200,80), rem=rn(150,50)
                var total=legA+legB+rem
                return {
                    q:"A "+total+" km road trip is planned. On day one, the car travels "+legA+" km. On day two, it travels "+legB+" km. How many km remain?",
                    a: total-legA-legB,
                    hint:"Subtract both days driven from the total distance."
                }
            }},
            { tag:"Better Deal", level:"Word Problems", gen: function() {
                var n1, n2, p1, p2, uA, uB
                do {
                    n1=rn(10,4); n2=rn(10,4)
                    p1=fix(rn(800,300)/100,2); p2=fix(rn(800,300)/100,2)
                    uA=fix(p1/n1,2); uB=fix(p2/n2,2)
                } while (uA === uB)   // re-roll on the rare exact tie
                return {
                    q:"Store A sells a "+n1+"-pack of batteries for $"+p1.toFixed(2)+". Store B sells a "+n2+"-pack for $"+p2.toFixed(2)+". What is the lower price per battery, rounded to the nearest cent?",
                    a: Math.min(uA,uB),
                    hint:"Divide each price by its pack size, then compare."
                }
            }},
            { tag:"Recipe Scaling", level:"Word Problems", gen: function() {
                var base=[2,4,6,8][ri(4)]
                var amount=fix(rn(6,2)*0.5,2)
                var mult=[0.5,1.5,2,2.5,3][ri(5)]
                var target=Math.round(base*mult)
                return {
                    q:"A recipe for "+base+" servings needs "+amount+" cups of flour. How many cups of flour are needed for "+target+" servings?",
                    a: fix(amount*target/base,2),
                    hint:"Find how much flour per serving, then multiply by the new serving count."
                }
            }},
            { tag:"Ticket Revenue", level:"Word Problems", gen: function() {
                var seats=rn(150,80), sold=rn(seats-20,20), price=fix(rn(1500,800)/100,2)
                return {
                    q:"A theater has "+seats+" seats. "+sold+" tickets have already been sold. Each remaining seat costs $"+price.toFixed(2)+". How much more revenue will the theater make if every remaining seat sells?",
                    a: fix((seats-sold)*price,2),
                    hint:"Subtract sold seats from total seats, then multiply by the ticket price."
                }
            }},
            { tag:"Closing Distance", level:"Word Problems", gen: function() {
                var dist=rn(300,60), speedA=rn(35,15), speedB=rn(35,15)
                return {
                    q:"Two towns are "+dist+" km apart. A cyclist leaves Town A at "+speedA+" km/h, and another leaves Town B at the same moment at "+speedB+" km/h, heading toward each other. About how many hours until they meet? (round to 1 decimal)",
                    a: fix(dist/(speedA+speedB),1),
                    hint:"Add both speeds together, then divide the distance by that combined speed."
                }
            }},
            { tag:"Discount", level:"Word Problems", gen: function() {
                var price=fix(rn(120,30),2), pct=[10,15,20,25,30,40][ri(6)]
                return {
                    q:"A jacket normally costs $"+price.toFixed(2)+". It's on sale for "+pct+"% off. What is the sale price?",
                    a: fix(price*(1-pct/100),2),
                    hint:"Find "+pct+"% of the price, then subtract that from the original price."
                }
            }},
        ]
    }

    function newMathProblem() {
        showHint = false; mathAnswer = ""; mathChecked = null
        // QOL FIX: the answer field used to keep showing whatever the user
        // last typed — mathAnswer reset above, but nothing ever told the
        // actual on-screen TextField (id: answerInput, in the quiz UI
        // below) to clear, since its `text` was never bound back to
        // mathAnswer. Skip/Next/Start all route through here, so fixing
        // it in one place covers all three.
        if (answerInput) answerInput.text = ""
        var filtered = difficulty === "Random" ? problemPool : problemPool.filter(function(p) { return p.level === difficulty })
        if (filtered.length === 0) return
        // QOL ("more unique quiz questions"): exclude problem types used in
        // the last 2 questions so the same generator can't fire back-to-
        // back. Falls back to the full filtered pool if that would leave
        // nothing pickable (e.g. a difficulty with very few tags left
        // after a couple of skips) — always better to repeat than to stall.
        var fresh = filtered.filter(function(p) { return root.recentGens.indexOf(p.tag + "|" + p.level) === -1 })
        var pickFrom = fresh.length > 0 ? fresh : filtered
        var entry  = pickFrom[Math.floor(Math.random() * pickFrom.length)]
        var result = entry.gen()
        currentTag   = (difficulty === "Random" ? "[" + entry.level + "] " : "") + entry.tag
        currentProb  = { q: result.q, a: result.a, hint: result.hint || "", level: entry.level }
        questionStartedAt = Date.now()
        root.recentGens = [entry.tag + "|" + entry.level].concat(root.recentGens).slice(0, 2)
    }

    function checkAnswer() {
        if (!currentProb || mathAnswer.trim() === "") return
        var user = parseFloat(mathAnswer)
        var correct = Math.abs(user - currentProb.a) < 0.01
        mathChecked = correct
        sessionTimes = sessionTimes.concat([(Date.now() - questionStartedAt) / 1000])

        if (correct) {
            mathScore = {right: mathScore.right+1, wrong: mathScore.wrong}
            streak++
            if (streak > sessionBestStreak) sessionBestStreak = streak
            quizStats.lifetimeRight++
            HapticHelper.click()
            if (streak > quizStats.bestStreak) {
                quizStats.bestStreak   = streak
                newBestThisSession     = true
                if (window) window.showToast("🏆 New best streak — " + streak + "!", true)
            } else if (window) {
                window.showToast("✓ Correct!" + (streak >= 3 ? "  🔥" + streak : ""), true)
            }
        } else {
            mathScore = {right: mathScore.right, wrong: mathScore.wrong+1}
            streak = 0
            quizStats.lifetimeWrong++
            HapticHelper.heavy()
            if (window) window.showToast("✗ Answer: " + currentProb.a)
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: Theme.sp4
        contentHeight: col.implicitHeight
        clip: true

        ColumnLayout {
            id: col
            width: parent.width
            spacing: Theme.sp4

            GroupTabs {
                Layout.fillWidth: true
                model: root.modes
                currentValue: root.mode
                onSelected: function(v) { root.mode = v }
            }

            // ── DICE ─────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.sp2
                visible: root.mode === "dice"
                spacing: Theme.sp4

                GroupTabs {
                    Layout.fillWidth: true
                    model: root.diceTypes.map(function(d) { return { label: "d"+d, value: d } })
                    currentValue: root.diceType
                    onSelected: function(v) { root.diceType = v }
                }
                RowLayout {
                    spacing: Theme.sp3
                    Text { text: "Count"; color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale) }
                    GroupTabs {
                        Layout.fillWidth: true
                        model: [1,2,3,4,5,6]
                        currentValue: root.diceCount
                        onSelected: function(v) { root.diceCount = v }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: Math.round(48 * Theme.scale); radius: Theme.rMd
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.accent2 }
                        GradientStop { position: 1.0; color: Theme.gradC }
                    }
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -2; radius: parent.radius + 2
                        color: "transparent"; border.width: 2; border.color: Theme.edgeB
                    }
                    Text { anchors.centerIn: parent; text: "Roll"; color: Theme.onAccent; font.family: Theme.fontSans; font.weight: Font.DemiBold; font.pixelSize: Math.round(14 * Theme.scale) }
                    scale: rollDiceTap.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: Theme.press } }
                    TapHandler { id: rollDiceTap; onTapped: root.rollDice() }
                }

                Flow {
                    Layout.fillWidth: true
                    visible: root.diceResults.length > 0
                    spacing: Theme.sp2
                    Repeater {
                        model: root.diceResults
                        delegate: Rectangle {
                            id: dieCell
                            width: Math.round(44 * Theme.scale); height: width; radius: Theme.rMd
                            color: Theme.surface
                            Text { anchors.centerIn: parent; text: modelData; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Math.round(17 * Theme.scale) }

                            // Each die pops in with a slight stagger by
                            // index, so several dice cascade in rather
                            // than appearing all at once — reads more like
                            // a roll settling than a static list.
                            scale: 0.3; opacity: 0
                            SequentialAnimation {
                                running: true
                                PauseAnimation { duration: index * 45 }
                                ParallelAnimation {
                                    NumberAnimation { target: dieCell; property: "scale";   to: 1.0; duration: Theme.bounceDuration; easing.type: Theme.bounceEasing; easing.overshoot: Theme.bounceOvershoot }
                                    NumberAnimation { target: dieCell; property: "opacity"; to: 1.0; duration: Theme.popDuration }
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: root.diceResults.length > 1
                    text: "Sum " + root.diceResults.reduce(function(a,b){return a+b},0)
                        + "  ·  Min " + Math.min.apply(null, root.diceResults)
                        + "  ·  Max " + Math.max.apply(null, root.diceResults)
                    color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale)
                }
            }

            // ── COIN ─────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.sp2
                visible: root.mode === "coin"
                spacing: Theme.sp4

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "H " + root.coinHistory.filter(function(c){return c==="H"}).length
                            + "   T " + root.coinHistory.filter(function(c){return c==="T"}).length
                        color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale)
                    }
                    Item { Layout.fillWidth: true }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(120 * Theme.scale)
                    visible: root.coinResult !== null
                    ColumnLayout {
                        id: coinResultCol
                        anchors.centerIn: parent
                        spacing: Theme.sp2
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.coinResult === "H" ? "🟡" : "⚫"
                            font.pixelSize: Math.round(52 * Theme.scale)
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.coinResult === "H" ? "HEADS" : "TAILS"
                            color: Theme.text; font.family: Theme.fontSans; font.weight: Font.Medium; font.pixelSize: Math.round(15 * Theme.scale)
                        }

                        // A coin landing gets a little spin + pop rather
                        // than just appearing — restarts on every new
                        // result (root.coinResult changing), not just the
                        // first reveal.
                        scale: 1.0; rotation: 0
                        SequentialAnimation {
                            id: coinLandAnim
                            ParallelAnimation {
                                NumberAnimation { target: coinResultCol; property: "scale"; from: 0.4; to: 1.0; duration: Theme.bounceDuration; easing.type: Theme.bounceEasing; easing.overshoot: Theme.bounceOvershoot }
                                NumberAnimation { target: coinResultCol; property: "rotation"; from: -200; to: 0; duration: Theme.bounceDuration + 120; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: Math.round(48 * Theme.scale); radius: Theme.rMd
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.accent2 }
                        GradientStop { position: 1.0; color: Theme.gradC }
                    }
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -2; radius: parent.radius + 2
                        color: "transparent"; border.width: 2; border.color: Theme.edgeB
                    }
                    Text { anchors.centerIn: parent; text: root.coinFlipping ? "…" : "Flip Coin"; color: Theme.onAccent; font.family: Theme.fontSans; font.weight: Font.DemiBold; font.pixelSize: Math.round(14 * Theme.scale) }
                    TapHandler { onTapped: root.flipCoin() }
                }
            }

            // ── RANGE ────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.sp2
                visible: root.mode === "range"
                spacing: Theme.sp4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp3
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: Theme.sp1
                        Text { text: "Min"; color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale) }
                        StyledInput { Layout.fillWidth: true; text: root.randMin; inputMethodHints: Qt.ImhDigitsOnly; onTextChanged: root.randMin = text }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: Theme.sp1
                        Text { text: "Max"; color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale) }
                        StyledInput { Layout.fillWidth: true; text: root.randMax; inputMethodHints: Qt.ImhDigitsOnly; onTextChanged: root.randMax = text }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: Math.round(48 * Theme.scale); radius: Theme.rMd
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.accent2 }
                        GradientStop { position: 1.0; color: Theme.gradC }
                    }
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -2; radius: parent.radius + 2
                        color: "transparent"; border.width: 2; border.color: Theme.edgeB
                    }
                    Text { anchors.centerIn: parent; text: "Pick"; color: Theme.onAccent; font.family: Theme.fontSans; font.weight: Font.DemiBold; font.pixelSize: Math.round(14 * Theme.scale) }
                    TapHandler { onTapped: root.pickRandom() }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.randResult !== null
                    text: String(root.randResult)
                    color: Theme.text; font.family: Theme.fontMono; font.weight: Font.Medium; font.pixelSize: Math.round(48 * Theme.scale)
                }
            }

            // ── QUIZ ─────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.sp2
                visible: root.mode === "quiz"
                spacing: Theme.sp3

                RowLayout {
                    Layout.fillWidth: true
                    visible: !root.showSummary && (root.mathScore.right + root.mathScore.wrong > 0 || root.quizStats.bestStreak > 0)
                    spacing: Theme.sp3
                    Text {
                        visible: root.mathScore.right + root.mathScore.wrong > 0
                        text: "✓ " + root.mathScore.right + "   ✗ " + root.mathScore.wrong
                        color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale)
                    }
                    Text { visible: root.streak >= 3; text: "🔥 " + root.streak; color: Theme.accent; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale) }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: root.quizStats.bestStreak > 0
                        text: "🏆 " + root.quizStats.bestStreak
                        color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale)
                    }
                    Text {
                        visible: root.mathScore.right + root.mathScore.wrong > 0
                        text: "reset"; color: Theme.textFaint; font.family: Theme.fontSans; font.pixelSize: Math.round(11 * Theme.scale)
                        TapHandler { onTapped: { root.mathScore = {right:0, wrong:0}; root.streak = 0; root.sessionBestStreak = 0; root.sessionTimes = [] } }
                    }
                }

                GroupTabs {
                    Layout.fillWidth: true
                    visible: !root.showSummary
                    model: root.difficulties.map(function(d) { return { label: root.diffIcons[d] + " " + d, value: d } })
                    currentValue: root.difficulty
                    onSelected: function(v) { root.difficulty = v; root.currentProb = null; root.mathChecked = null; root.showHint = false }
                }

                // NEW — session length. Picking a fixed length turns the
                // quiz into a real round with a start and an end (see the
                // summary card below) instead of an endless drip of
                // questions; "Endless" keeps the original open-ended feel.
                GroupTabs {
                    Layout.fillWidth: true
                    visible: !root.showSummary
                    model: root.quizLengths
                    currentValue: root.quizLength
                    onSelected: function(v) { root.quizLength = v; root.currentProb = null; root.mathChecked = null; root.showHint = false }
                }

                Rectangle {
                    id: startBtn
                    Layout.fillWidth: true; Layout.preferredHeight: Math.round(48 * Theme.scale); radius: Theme.rMd
                    visible: !root.showSummary && root.currentProb === null
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.gradA }
                        GradientStop { position: 0.5; color: Theme.gradB }
                        GradientStop { position: 1.0; color: Theme.gradC }
                    }
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -2; radius: parent.radius + 2
                        color: "transparent"; border.width: 2; border.color: Theme.edgeA
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "Start — " + root.difficulty + (root.quizLength !== "∞" ? " · " + root.quizLength + "Q" : "")
                        color: Theme.onAccent; font.family: Theme.fontSans; font.weight: Font.DemiBold; font.pixelSize: Math.round(14 * Theme.scale)
                    }

                    scale: 1.0
                    NumberAnimation { id: startPressDown;  target: startBtn; property: "scale"; to: 0.95; duration: Theme.press; easing.type: Easing.OutQuad }
                    NumberAnimation { id: startBounceBack; target: startBtn; property: "scale"; to: 1.0;  duration: Theme.bounceDuration; easing.type: Theme.bounceEasing; easing.overshoot: Theme.bounceOvershoot }
                    TapHandler {
                        onPressedChanged: {
                            if (pressed) { startBounceBack.stop(); startPressDown.restart() }
                            else { startPressDown.stop(); startBounceBack.restart() }
                        }
                        // Was newMathProblem() directly — now routes through
                        // startNewSession() so the score/streak/timing for
                        // THIS round start at zero rather than continuing
                        // to accumulate onto whatever was left over from
                        // whatever was played before (see startNewSession).
                        onTapped: root.startNewSession()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !root.showSummary && root.currentProb !== null
                    spacing: Theme.sp3

                    Text {
                        visible: root.currentTag !== ""
                        text: root.currentTag + (root.quizLength !== "∞"
                            ? "   ·   Q" + (root.mathScore.right + root.mathScore.wrong + 1) + "/" + root.quizLength
                            : "")
                        color: Theme.accent2; font.family: Theme.fontSans; font.pixelSize: Math.round(11 * Theme.scale)
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: Math.max(Math.round(72 * Theme.scale), qText.implicitHeight + Theme.sp4 * 2)
                        radius: Theme.rMd
                        // Correct/wrong now map to green/red (was blue/red) — a more
                        // intuitive convention now that green is part of the palette.
                        color: root.mathChecked === true ? Qt.rgba(Theme.gradB.r, Theme.gradB.g, Theme.gradB.b, 0.12)
                             : root.mathChecked === false ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                             : Theme.surface
                        Text {
                            id: qText
                            anchors.centerIn: parent
                            width: parent.width - Theme.sp4 * 2
                            text: root.currentProb ? root.currentProb.q : ""
                            color: Theme.text
                            // Word Problems get a reading-friendly style — left-aligned,
                            // regular-weight, plain sans — instead of the centered bold
                            // mono used for short expressions. A 2-3 sentence paragraph
                            // set in bold centered monospace reads like a code snippet,
                            // not prose, and centered alignment makes multi-line text
                            // genuinely harder to read line to line.
                            readonly property bool isWordProblem: root.currentProb !== null && root.currentProb.level === "Word Problems"
                            font.family: isWordProblem ? Theme.fontSans : Theme.fontMono
                            font.weight: isWordProblem ? Font.Normal : Font.DemiBold
                            font.pixelSize: Math.round((isWordProblem ? 15 : (root.currentProb && root.currentProb.q.length > 20 ? 16 : 21)) * Theme.scale)
                            horizontalAlignment: isWordProblem ? Text.AlignLeft : Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.showHint && root.currentProb !== null && (root.currentProb.hint || "") !== ""
                        text: "💡 " + (root.currentProb ? root.currentProb.hint || "" : "")
                        color: Theme.accent2; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale)
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.currentProb !== null && root.mathChecked === null
                        spacing: Theme.sp2

                        StyledInput {
                            id: answerInput
                            Layout.fillWidth: true
                            placeholderText: "Your answer…"
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            onTextChanged: root.mathAnswer = text
                            Keys.onReturnPressed: root.checkAnswer()
                        }
                        Text {
                            visible: root.currentProb !== null && (root.currentProb.hint || "") !== ""
                            text: "hint"; color: Theme.accent2; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale)
                            TapHandler { onTapped: root.showHint = !root.showHint }
                        }
                        Text {
                            text: "Check"; color: Theme.accent; font.family: Theme.fontSans; font.weight: Font.DemiBold; font.pixelSize: Math.round(13 * Theme.scale)
                            TapHandler { onTapped: root.checkAnswer() }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.mathChecked !== null
                        spacing: Theme.sp3
                        Text {
                            Layout.fillWidth: true
                            text: root.mathChecked ? "✓ Correct!" + (root.streak >= 3 ? "  🔥" + root.streak : "") : "✗ Answer: " + (root.currentProb ? root.currentProb.a : "")
                            color: root.mathChecked ? Theme.gradB : Theme.accent
                            font.family: Theme.fontSans; font.pixelSize: Math.round(13 * Theme.scale)
                        }
                        Text {
                            text: root.sessionComplete ? "See Results →" : "Next →"
                            color: Theme.accent2; font.family: Theme.fontSans; font.weight: Font.Medium; font.pixelSize: Math.round(12 * Theme.scale)
                            TapHandler { onTapped: root.sessionComplete ? root.finishSession() : root.newMathProblem() }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignRight
                        visible: root.currentProb !== null && root.mathChecked === null
                        text: "skip"; color: Theme.textFaint; font.family: Theme.fontSans; font.pixelSize: Math.round(11 * Theme.scale)
                        TapHandler { onTapped: root.newMathProblem() }
                    }
                }

                // ── Session summary ─────────────────────────────────────
                // Shown once a fixed-length session's last question has
                // been answered (see sessionComplete + finishSession()).
                // Endless mode never reaches this — sessionComplete is
                // always false when quizLength === "∞".
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.showSummary
                    spacing: Theme.sp3

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: summaryCol.implicitHeight + Theme.sp4 * 2
                        radius: Theme.rMd
                        color: Theme.surface

                        Rectangle {
                            anchors.fill: parent; anchors.margins: -1
                            radius: parent.radius + 1
                            color: "transparent"; border.width: 1; border.color: Theme.edgeA
                        }

                        ColumnLayout {
                            id: summaryCol
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: Theme.sp4
                            spacing: Theme.sp2

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "SESSION COMPLETE"
                                color: Theme.textFaint; font.family: Theme.fontSans; font.weight: Font.Bold; font.pixelSize: Math.round(10 * Theme.scale)
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.mathScore.right + " / " + (root.mathScore.right + root.mathScore.wrong)
                                color: Theme.text; font.family: Theme.fontMono; font.weight: Font.DemiBold; font.pixelSize: Math.round(36 * Theme.scale)
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: (root.mathScore.right + root.mathScore.wrong > 0
                                    ? Math.round(100 * root.mathScore.right / (root.mathScore.right + root.mathScore.wrong))
                                    : 0) + "% correct"
                                color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(13 * Theme.scale)
                            }

                            Rectangle { Layout.fillWidth: true; Layout.topMargin: Theme.sp2; Layout.bottomMargin: Theme.sp1; height: 1; color: Theme.surface2 }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { Layout.fillWidth: true; text: "🔥 Best streak"; color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale) }
                                Text { text: String(root.sessionBestStreak); color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Math.round(12 * Theme.scale) }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                visible: root.sessionTimes.length > 0
                                Text { Layout.fillWidth: true; text: "⏱ Avg time"; color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale) }
                                Text { text: root.avgSessionTime().toFixed(1) + "s"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Math.round(12 * Theme.scale) }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: root.newBestThisSession ? "🏆 New all-time best!" : "🏆 All-time best"
                                    color: root.newBestThisSession ? Theme.accent : Theme.textDim
                                    font.family: Theme.fontSans; font.weight: root.newBestThisSession ? Font.DemiBold : Font.Normal; font.pixelSize: Math.round(12 * Theme.scale)
                                }
                                Text { text: String(root.quizStats.bestStreak); color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Math.round(12 * Theme.scale) }
                            }
                        }
                    }

                    Rectangle {
                        id: playAgainBtn
                        Layout.fillWidth: true; Layout.preferredHeight: Math.round(48 * Theme.scale); radius: Theme.rMd
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Theme.gradA }
                            GradientStop { position: 0.5; color: Theme.gradB }
                            GradientStop { position: 1.0; color: Theme.gradC }
                        }
                        Rectangle {
                            anchors.fill: parent; anchors.margins: -2; radius: parent.radius + 2
                            color: "transparent"; border.width: 2; border.color: Theme.edgeA
                        }
                        Text { anchors.centerIn: parent; text: "Play Again"; color: Theme.onAccent; font.family: Theme.fontSans; font.weight: Font.DemiBold; font.pixelSize: Math.round(14 * Theme.scale) }

                        scale: 1.0
                        NumberAnimation { id: playAgainPressDown;  target: playAgainBtn; property: "scale"; to: 0.95; duration: Theme.press; easing.type: Easing.OutQuad }
                        NumberAnimation { id: playAgainBounceBack; target: playAgainBtn; property: "scale"; to: 1.0;  duration: Theme.bounceDuration; easing.type: Theme.bounceEasing; easing.overshoot: Theme.bounceOvershoot }
                        TapHandler {
                            onPressedChanged: {
                                if (pressed) { playAgainBounceBack.stop(); playAgainPressDown.restart() }
                                else { playAgainPressDown.stop(); playAgainBounceBack.restart() }
                            }
                            onTapped: root.startNewSession()
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "change settings"
                        color: Theme.textFaint; font.family: Theme.fontSans; font.pixelSize: Math.round(11 * Theme.scale)
                        TapHandler { onTapped: root.backToSettings() }
                    }
                }
            }
        }
    }
}
