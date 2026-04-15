cmake_minimum_required(VERSION 3.16)
project(SmartCalc VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network Qml QuickControls2)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(SmartCalc
    main.cpp
    backend/MathEngine.cpp
    backend/MathEngine.h
    backend/AppSettings.cpp
    backend/AppSettings.h
    backend/ApiClient.cpp
    backend/ApiClient.h
)

# CRASH FIX: Theme.qml uses `pragma Singleton` — Qt 6.5+ requires this property
# to be declared explicitly, otherwise the generated qmldir marks Theme as a
# regular (non-singleton) type.  At runtime Qt 6.7+ treats the pragma/qmldir
# mismatch as a fatal error, causing the entire SmartCalc.Backend module to
# fail loading → objectCreationFailed → QCoreApplication::exit(-1) → crash.
# The black background the user sees is the Android system splash, not QML.
set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(SmartCalc
    URI SmartCalc.Backend
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/CalcTab.qml
        qml/FormulaTab.qml
        qml/ConvertTab.qml
        qml/RandomTab.qml
        qml/GraphTab.qml
        qml/AITab.qml
        qml/components/AppTabBar.qml
        qml/components/CalcButton.qml
        qml/components/StyledInput.qml
        qml/components/UnitPill.qml
        qml/components/ToastMessage.qml
        qml/Theme.qml
)

set_target_properties(SmartCalc PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER com.smartcalc.app
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_include_directories(SmartCalc PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/backend
)

target_link_libraries(SmartCalc PRIVATE
    Qt6::Quick
    Qt6::Network
    Qt6::Qml
    Qt6::QuickControls2
)

# Android config
if(ANDROID)
    set(QT_ANDROID_MIN_SDK_VERSION 28)
    set(QT_ANDROID_TARGET_SDK_VERSION 35)
    set_property(TARGET SmartCalc APPEND PROPERTY QT_ANDROID_PACKAGE_SOURCE_DIR
                 ${CMAKE_CURRENT_SOURCE_DIR}/android)
endif()

# ── Android 16KB page-size support (required for Android 15+ devices) ─────────
# The workflow uses zipalign -p 16384 to align the APK for 16KB pages.
# Without this matching linker flag, libSmartCalc.so's ELF segments stay at 4KB
# alignment and dlopen() kills the process before main() runs.
if(ANDROID)
    target_link_options(SmartCalc PRIVATE "-Wl,-z,max-page-size=16384")
endif()
