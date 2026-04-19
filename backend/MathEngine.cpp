#include "MathEngine.h"
#include <QJSValue>
#include <QMap>
#include <QtMath>
#include <cmath>

MathEngine::MathEngine(QObject *parent)
    : QObject(parent)
{
    loadMathLibrary();
}

void MathEngine::loadMathLibrary()
{
    const QString mathSetup = R"JS(
        var _M = {};
        _M.PI = Math.PI;
        _M.E  = Math.E;
        _M.PHI = 1.6180339887498948482;

        _M._deg = true;
        _M._toRad = function(x) { return _M._deg ? x * Math.PI / 180 : x; };
        _M._fromRad = function(x) { return _M._deg ? x * 180 / Math.PI : x; };

        _M.sin  = function(x){ return Math.sin(_M._toRad(x)); };
        _M.cos  = function(x){ return Math.cos(_M._toRad(x)); };
        _M.tan  = function(x){ return Math.tan(_M._toRad(x)); };
        _M.asin = function(x){ return _M._fromRad(Math.asin(x)); };
        _M.acos = function(x){ return _M._fromRad(Math.acos(x)); };
        _M.atan = function(x){ return _M._fromRad(Math.atan(x)); };
        _M.sinh = function(x){ return Math.sinh(x); };
        _M.cosh = function(x){ return Math.cosh(x); };
        _M.tanh = function(x){ return Math.tanh(x); };

        _M.sqrt  = Math.sqrt;
        _M.cbrt  = Math.cbrt;
        _M.abs   = Math.abs;
        _M.log   = function(x){ return Math.log10(x); };
        _M.log10 = Math.log10;
        _M.log2  = Math.log2;   // FIX #32: was defined but missing — log2(x) returned ReferenceError
        _M.ln    = function(x){ return Math.log(x); };
        _M.exp   = Math.exp;
        _M.floor = Math.floor;
        _M.ceil  = Math.ceil;
        _M.round = Math.round;
        _M.pow   = Math.pow;
        _M.sign  = Math.sign;

        _M.factorial = function(n) {
            n = Math.round(Math.abs(n));
            if (n > 170) return Infinity;
            var r = 1;
            for (var i = 2; i <= n; i++) r *= i;
            return r;
        };
        _M.fact = _M.factorial;
        _M.nCr = function(n,r){
            n=Math.round(n); r=Math.round(r);
            if(r<0||r>n) return 0;
            if(r===0||r===n) return 1;
            if(r>n-r) r=n-r;          // use smaller side to minimise iterations
            var result=1;
            for(var i=0;i<r;i++){
                result=result*(n-i)/(i+1);  // multiply then divide keeps value bounded
            }
            return Math.round(result);
        };
        _M.nPr = function(n,r){
            n=Math.round(n); r=Math.round(r);
            if(r<0||r>n) return 0;
            if(r===0) return 1;
            var result=1;
            for(var i=0;i<r;i++){
                result*=(n-i);
                if(!isFinite(result)) return Infinity;
            }
            return result;
        };
        _M.gcd = function(a,b){
            a=Math.round(Math.abs(a)); b=Math.round(Math.abs(b));
            while(b){var t=b;b=a%b;a=t;} return a;
        };
        _M.lcm = function(a,b){ return Math.abs(a*b)/_M.gcd(a,b); };

        // SECURITY: expression passed via _evalExpr global — no string injection.
        _M.eval = function(expr) {
            var e = expr
                .replace(/\xd7/g,'*').replace(/\xf7/g,'/').replace(/\u2212/g,'-')
                .replace(/\u03c0/g, _M.PI)
                .replace(/\bpi\b/gi, _M.PI)
                .replace(/\be\b/g, _M.E)
                .replace(/\bphi\b/gi, _M.PHI)
                .replace(/\^/g,'**')
                .replace(/\u221a\(/g,'_M.sqrt(')
                .replace(/\bsqrt\(/g,'_M.sqrt(')
                .replace(/\bcbrt\(/g,'_M.cbrt(')
                .replace(/\bsin\(/g,'_M.sin(')
                .replace(/\bcos\(/g,'_M.cos(')
                .replace(/\btan\(/g,'_M.tan(')
                .replace(/\basin\(/g,'_M.asin(')
                .replace(/\bacos\(/g,'_M.acos(')
                .replace(/\batan\(/g,'_M.atan(')
                .replace(/\bsinh\(/g,'_M.sinh(')
                .replace(/\bcosh\(/g,'_M.cosh(')
                .replace(/\btanh\(/g,'_M.tanh(')
                .replace(/\babs\(/g,'_M.abs(')
                .replace(/\bln\(/g,'_M.ln(')
                .replace(/\bexp\(/g,'_M.exp(')
                .replace(/\bfloor\(/g,'_M.floor(')
                .replace(/\bceil\(/g,'_M.ceil(')
                .replace(/\bround\(/g,'_M.round(')
                // FIX #32: sign() and log2() were defined on _M but their \b-replace
                // entries were missing, so calling sign(-1) or log2(8) in the Calc /
                // Formula / Convert tabs hit a JS ReferenceError → "Error" result.
                // log2 must precede log to avoid a (harmless but wasteful) partial match.
                .replace(/\bsign\(/g,'_M.sign(')
                .replace(/\blog2\(/g,'_M.log2(')
                .replace(/\blog10\(/g,'_M.log10(')
                .replace(/\blog\(/g,'_M.log(')
                .replace(/\bnCr\(/g,'_M.nCr(')
                .replace(/\bnPr\(/g,'_M.nPr(')
                .replace(/\bgcd\(/g,'_M.gcd(')
                .replace(/\blcm\(/g,'_M.lcm(');
            return eval(e);
        };
    )JS";
    m_engine.evaluate(mathSetup);
}

QString MathEngine::evaluate(const QString &expression, bool degrees, bool fracMode)
{
    if (expression.isEmpty() || expression == "0")
        return "0";

    m_degrees = degrees;
    m_engine.evaluate(QString("_M._deg = %1;").arg(degrees ? "true" : "false"));

    // SECURITY FIX: pass expression as a JS property, never string-interpolate into eval().
    const QString safeExpr = expression.simplified();
    m_engine.globalObject().setProperty("_evalExpr", safeExpr);
    QJSValue result = m_engine.evaluate("_M.eval(_evalExpr)");

    if (result.isError())
        return "Error";

    double num = result.toNumber();
    if (std::isnan(num) || std::isinf(num))
        return result.toString();

    if (fracMode) {
        for (int d = 2; d <= 9999; d++) {
            long long n = std::llround(num * d);
            if (std::abs(num - (double)n / d) < 1e-10) {
                if (n % d == 0) break;
                // BUG FIX: was producing "-/abs(n)/d" — now correctly "-abs(n)/d"
                long long absN = std::abs(n);
                QString sign = (n < 0) ? QStringLiteral("-") : QStringLiteral("");
                return QString("%1%2/%3").arg(sign).arg(absN).arg(d);
            }
        }
    }

    return formatNumber(num);
}

// ── Recursive-descent parser for graph expressions ──────────────────────────
// Replaces the previous JS eval() path entirely.  No QJSEngine involvement.
//
// Grammar (EBNF):
//   expr    = sum
//   sum     = product { ('+' | '-' | '−') product }
//   product = unary   { ('*' | '×' | '/' | '÷' | implicit) unary }
//   unary   = ('-' | '−' | '+') unary | power
//   power   = call { '^' unary }                   ← right-associative
//   call    = '√' call                             ← prefix sqrt
//           | IDENT '(' expr ')'                   ← named function call
//           | IDENT                                ← constant: x, pi, π, e, phi
//           | '(' expr ')'
//           | NUMBER
//   NUMBER  = digit+ ['.' digit*] [('e'|'E') ['+'|'-'] digit+]
//
// Implicit multiplication fires in parseProd whenever the token after lhs
// starts with '(', a letter, '√', or 'π' — anything that opens a new unary.
// Greedy identifier reading keeps "exp", "sin", "xor"-style names intact.

namespace {

struct GParser {
    const QChar *p;
    const QChar *end;
    double       xVal;
    bool         degrees;
    bool         ok = true;

    static constexpr double kPhi = 1.6180339887498948482;

    GParser(const QString &s, double x, bool deg)
        : p(s.constData()), end(s.constData() + s.size()), xVal(x), degrees(deg) {}

    double toRad  (double v) const { return degrees ? v * M_PI / 180.0 : v; }
    double fromRad(double v) const { return degrees ? v * 180.0 / M_PI : v; }

    void  skipWs() { while (p < end && p->isSpace()) ++p; }
    QChar peek()   { skipWs(); return (p < end) ? *p : QChar(0); }
    bool  eat(QChar c) { if (peek() == c) { ++p; return true; } return false; }

    static double nan() { return std::numeric_limits<double>::quiet_NaN(); }

    double parse() { return parseExpr(); }

    double parseExpr() { return parseSum(); }

    double parseSum() {
        double lhs = parseProd();
        while (true) {
            QChar c = peek();
            if      (c == '+')              { ++p; lhs += parseProd(); }
            else if (c == '-' || c == QChar(0x2212)) { ++p; lhs -= parseProd(); }
            else break;
        }
        return lhs;
    }

    double parseProd() {
        double lhs = parseUnary();
        while (true) {
            QChar c = peek();
            if (c == '*' || c == QChar(0x00D7)) {          // explicit * or ×
                ++p; lhs *= parseUnary();
            } else if (c == '/' || c == QChar(0x00F7)) {   // explicit / or ÷
                ++p;
                double rhs = parseUnary();
                lhs = (rhs == 0.0) ? nan() : lhs / rhs;
            } else if (c == '(' || c == QChar(0x221A) ||   // implicit mult
                       c == QChar(0x03C0) || c.isLetter()) {
                lhs *= parseUnary();
            } else {
                break;
            }
        }
        return lhs;
    }

    double parseUnary() {
        QChar c = peek();
        if (c == '-' || c == QChar(0x2212)) { ++p; return -parsePower(); }
        if (c == '+')                        { ++p; return  parsePower(); }
        return parsePower();
    }

    double parsePower() {   // right-associative
        double base = parseCall();
        if (peek() == '^') { ++p; return std::pow(base, parseUnary()); }
        return base;
    }

    double parseCall() {
        QChar c = peek();

        if (c == QChar(0x221A)) { ++p; return std::sqrt(parsePower()); } // '√'

        if (c == '(') {
            ++p;
            double v = parseExpr();
            if (!eat(')')) ok = false;
            return v;
        }

        if (c.isDigit() || c == '.') return parseNumber();

        if (c == QChar(0x03C0)) { ++p; return M_PI; }  // 'π'

        if (c.isLetter()) {
            skipWs();
            QString name;
            while (p < end && (p->isLetterOrNumber() || *p == '_'))
                name += *p++;

            // Constants
            if (name.compare("pi",  Qt::CaseInsensitive) == 0) return M_PI;
            if (name.compare("phi", Qt::CaseInsensitive) == 0) return kPhi;
            if (name == "x" || name == "X") return xVal;
            if (name == "e")                return M_E;   // lowercase only; 'E' in "1E5" is consumed by parseNumber

            // Functions — parenthesis required
            if (!eat('(')) { ok = false; return nan(); }
            double a = parseExpr();
            if (!eat(')')) ok = false;

            if (name == "sin")                    return std::sin(toRad(a));
            if (name == "cos")                    return std::cos(toRad(a));
            if (name == "tan")                    return std::tan(toRad(a));
            if (name == "asin")                   return fromRad(std::asin(a));
            if (name == "acos")                   return fromRad(std::acos(a));
            if (name == "atan")                   return fromRad(std::atan(a));
            if (name == "sinh")                   return std::sinh(a);
            if (name == "cosh")                   return std::cosh(a);
            if (name == "tanh")                   return std::tanh(a);
            if (name == "sqrt")                   return std::sqrt(a);
            if (name == "cbrt")                   return std::cbrt(a);
            if (name == "abs")                    return std::fabs(a);
            if (name == "log" || name == "log10") return std::log10(a);
            if (name == "ln")                     return std::log(a);
            if (name == "exp")                    return std::exp(a);
            if (name == "floor")                  return std::floor(a);
            if (name == "ceil")                   return std::ceil(a);
            if (name == "round")                  return std::round(a);
            if (name == "sign")                   return static_cast<double>((a > 0) - (a < 0));
            // FIX #32: log2(x) and sgn(x) were not in the GParser table — both
            // silently returned NaN for every pixel, producing a blank graph with
            // no error message (identical to "no functions added").
            if (name == "sgn")                    return static_cast<double>((a > 0) - (a < 0));
            if (name == "log2")                   return std::log2(a);

            ok = false; return nan();
        }

        ok = false; return nan();
    }

    // Parses a numeric literal, including scientific notation (e.g. "1.5e-3").
    // Consuming the 'e'/'E' here prevents it from being mistaken for Euler's number.
    double parseNumber() {
        skipWs();
        const QChar *start = p;
        while (p < end && p->isDigit()) ++p;
        if (p < end && *p == '.') { ++p; while (p < end && p->isDigit()) ++p; }
        if (p < end && (*p == 'e' || *p == 'E')) {
            const QChar *save = p; ++p;
            if (p < end && (*p == '+' || *p == '-')) ++p;
            if (p < end && p->isDigit()) { while (p < end && p->isDigit()) ++p; }
            else p = save;  // backtrack — not scientific notation
        }
        QByteArray bytes;
        bytes.reserve(static_cast<int>(p - start));
        for (const QChar *q = start; q < p; ++q) bytes += static_cast<char>(q->toLatin1());
        bool convOk = false;
        double val = bytes.toDouble(&convOk);
        if (!convOk) { ok = false; return nan(); }
        return val;
    }
};

} // anonymous namespace

// evaluateAt — pure C++ evaluation; no QJSEngine / JS eval() involved.
// The GParser above handles the full graph expression grammar:
//   ^, all trig/log/exp functions, sqrt, floor, ceil, abs, pi, e, phi,
//   binary arithmetic, and implicit multiplication ("2x", "3sin(x)", etc.).
double MathEngine::evaluateAt(const QString &expression, double x)
{
    GParser gp(expression.simplified(), x, m_degrees);
    return gp.parse();   // NaN propagates naturally on parse error (gp.ok=false)
}

QString MathEngine::formatNumber(double value) const
{
    if (std::isnan(value))  return "NaN";
    if (std::isinf(value))  return value > 0 ? "∞" : "-∞";
    return QString::number(value, 'g', 12);
}

double MathEngine::convertUnit(double value,
                                const QString &fromUnit,
                                const QString &toUnit,
                                const QString &category) const
{
    if (category == "Temperature") {
        if (fromUnit == toUnit) return value;
        double celsius;
        if (fromUnit == "°C")      celsius = value;
        else if (fromUnit == "°F") celsius = (value - 32.0) * 5.0 / 9.0;
        else                       celsius = value - 273.15;
        if (toUnit == "°C")      return celsius;
        if (toUnit == "°F")      return celsius * 9.0 / 5.0 + 32.0;
        return celsius + 273.15;
    }

    static const QMap<QString, double> toBase {
        {"mm",1e-3},{"cm",1e-2},{"m",1.0},{"km",1e3},
        {"in",0.0254},{"ft",0.3048},{"yd",0.9144},{"mi",1609.344},
        {"g",1e-3},{"kg",1.0},{"lb",0.453592},{"oz",0.0283495},{"t",1e3},
        {"m/s",1.0},{"km/h",1.0/3.6},{"mph",0.44704},
        {"ml",1e-3},{"l",1.0},{"gal",3.78541},{"cup",0.236588},
        {"s",1.0},{"min",60.0},{"hr",3600.0},
        {"day",86400.0},{"wk",604800.0},{"mo",2629800.0},{"yr",31557600.0},
        {"B",1.0},{"KB",1024.0},{"MB",1048576.0},
        {"GB",1073741824.0},{"TB",1099511627776.0},
    };

    if (!toBase.contains(fromUnit) || !toBase.contains(toUnit))
        return value;

    return value * toBase[fromUnit] / toBase[toUnit];
}
