cmake_minimum_required(VERSION 3.16)
project(SmartCalc VERSION 1.0 LANGUAGES CXX)

# ── Version history ───────────────────────────────────────────────────────────
# v76 → v77:
#  • HapticHelper: 18ms click on every CalcButton press, 38ms thud on = and C
#  • CalcButton uses TapHandler instead of MouseArea for proper multi-touch:
#    pressing several buttons at once now all register independently
#  • Responsive button grid: Layout.fillHeight fills available screen height
#  • Shadow ring on every button + adaptive radius for any button size
# ─────────────────────────────────────────────────────────────────────────────

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network Qml QuickControls2)
if(ANDROID)
    find_package(Qt6 COMPONENTS Core REQUIRED)
endif()
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(SmartCalc
    main.cpp
    backend/MathEngine.cpp
    backend/MathEngine.h
    backend/AppSettings.cpp
    backend/AppSettings.h
    backend/ApiClient.cpp
    backend/ApiClient.h
    backend/FileHelper.cpp      # v75: file/image reading for AI vision
    backend/FileHelper.h
    backend/HapticHelper.cpp   # v77: tactile feedback on Android
    backend/HapticHelper.h
)

# CRASH FIX: Theme.qml uses `pragma Singleton` — Qt 6.5+ requires this
# property to be declared explicitly, otherwise the generated qmldir marks
# Theme as a regular (non-singleton) type. Qt 6.7+ treats the mismatch as
# fatal → objectCreationFailed → QCoreApplication::exit(-1) → crash.
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
        qml/ProgrammerTab.qml   # v75: programmer / bit-toggler tab
        qml/AITab.qml
        qml/components/AppTabBar.qml
        qml/components/CalcButton.qml
        qml/components/StyledInput.qml
        qml/components/UnitPill.qml
        qml/components/ToastMessage.qml
        qml/components/TabIcon.qml          # v76: custom icon loader w/ fallback
        qml/components/MoreSheet.qml        # v79: slide-up overflow sheet
        qml/Theme.qml
    # ── Custom tab icons (optional) ──────────────────────────────────────────
    # Drop an image into qml/icons/ named after the tab label (lowercase):
    #   calc, formula, convert, random, graph, prog, ai
    # Supported extensions (tried in order): .png  .svg  .jpg
    # Then add the file path here and rebuild. Max size: 48×48 px recommended.
    # Example:
    #   RESOURCES
    #       qml/icons/calc.png
    #       qml/icons/formula.svg
    RESOURCES
        qml/icons/README.md
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
if(ANDROID)
    target_link_libraries(SmartCalc PRIVATE Qt6::CorePrivate)
endif()

# Android config
if(ANDROID)
    set(QT_ANDROID_MIN_SDK_VERSION 28)
    set(QT_ANDROID_TARGET_SDK_VERSION 35)
    set_property(TARGET SmartCalc APPEND PROPERTY QT_ANDROID_PACKAGE_SOURCE_DIR
                 ${CMAKE_CURRENT_SOURCE_DIR}/android)
endif()

# ── Android 16 KB page-size support (required for Android 15+ devices) ────────
# The workflow uses zipalign -p 16384 to align the APK for 16KB pages.
# Without this matching linker flag libSmartCalc.so's ELF segments stay at 4 KB
# alignment and dlopen() kills the process before main() runs.
if(ANDROID)
    target_link_options(SmartCalc PRIVATE "-Wl,-z,max-page-size=16384")
endif()
