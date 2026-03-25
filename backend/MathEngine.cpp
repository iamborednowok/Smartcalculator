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
            return _M.factorial(n)/(_M.factorial(r)*_M.factorial(n-r));
        };
        _M.nPr = function(n,r){
            n=Math.round(n); r=Math.round(r);
            if(r<0||r>n) return 0;
            return _M.factorial(n)/_M.factorial(n-r);
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
                .replace(/\blog10\(/g,'_M.log10(')
                .replace(/\blog\(/g,'_M.log(')
                .replace(/\bln\(/g,'_M.ln(')
                .replace(/\bexp\(/g,'_M.exp(')
                .replace(/\bfloor\(/g,'_M.floor(')
                .replace(/\bceil\(/g,'_M.ceil(')
                .replace(/\bround\(/g,'_M.round(')
                .replace(/\bfact\(/g,'_M.fact(')
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
