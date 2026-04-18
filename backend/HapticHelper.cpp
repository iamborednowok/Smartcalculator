#include "HapticHelper.h"

#ifdef Q_OS_ANDROID
#include <QJniObject>
// Qt 6.2+: QNativeInterface lives in QtCore/qnativeinterface.h (lowercase).
// The umbrella <QNativeInterface> header is missing on some NDK toolchains,
// so we include the canonical path directly.
#if __has_include(<QtCore/qnativeinterface.h>)
#  include <QtCore/qnativeinterface.h>
#endif
#endif

HapticHelper::HapticHelper(QObject *parent) : QObject(parent) {}

// ── Internal helper ────────────────────────────────────────────────────────────
#ifdef Q_OS_ANDROID
static void androidVibrate(jlong durationMs, jint amplitude)
{
    // amplitude: -1 = DEFAULT_AMPLITUDE, 1-255 explicit
    //
    // Prefer QNativeInterface if the header resolved; fall back to the stable
    // QtNative JNI call that works across all Qt 6 + NDK 27 toolchains.
#if defined(QT_CORE_LIB) && __has_include(<QtCore/qnativeinterface.h>)
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
#else
    // Fallback: ask Qt's internal Java layer for the current Activity.
    QJniObject activity = QJniObject::callStaticObjectMethod(
        "org/qtproject/qt/android/QtNative",
        "activity",
        "()Landroid/app/Activity;"
    );
#endif
    if (!activity.isValid()) return;

    QJniObject vibratorManager = activity.callObjectMethod(
        "getSystemService",
        "(Ljava/lang/String;)Ljava/lang/Object;",
        QJniObject::fromString("vibrator_manager").object<jstring>()
    );

    // Fallback to legacy "vibrator" service if VibratorManager isn't available (API < 31)
    QJniObject vibrator;
    if (vibratorManager.isValid()) {
        vibrator = vibratorManager.callObjectMethod(
            "getDefaultVibrator",
            "()Landroid/os/Vibrator;"
        );
    } else {
        vibrator = activity.callObjectMethod(
            "getSystemService",
            "(Ljava/lang/String;)Ljava/lang/Object;",
            QJniObject::fromString("vibrator").object<jstring>()
        );
    }

    if (!vibrator.isValid()) return;

    // VibrationEffect.createOneShot (API 26+)
    QJniObject effect = QJniObject::callStaticObjectMethod(
        "android/os/VibrationEffect",
        "createOneShot",
        "(JI)Landroid/os/VibrationEffect;",
        durationMs,
        amplitude
    );
    if (effect.isValid()) {
        vibrator.callMethod<void>(
            "vibrate",
            "(Landroid/os/VibrationEffect;)V",
            effect.object<jobject>()
        );
    }
}
#endif

// ── Public API ─────────────────────────────────────────────────────────────────

void HapticHelper::click()
{
#ifdef Q_OS_ANDROID
    androidVibrate(18, -1);   // 18 ms, default amplitude → crisp click
#endif
}

void HapticHelper::heavy()
{
#ifdef Q_OS_ANDROID
    androidVibrate(38, 200);  // 38 ms, strong amplitude → satisfying thud
#endif
}
