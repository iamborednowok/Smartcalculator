cmake_minimum_required(VERSION 3.16)
project(SmartCalc VERSION 1.0 LANGUAGES CXX)

# Design/architecture is documented in REBUILD_NOTES.md at the project root.

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
        qml/ProgrammerTab.qml
        qml/AITab.qml
        qml/components/CalcButton.qml
        qml/components/GroupTabs.qml        # reusable ribbon-style group selector
        qml/components/TabPillBar.qml        # one nav for every orientation (replaced TopRibbon/AppTabBar/MoreSheet)
        qml/components/AmbientGlow.qml       # decorative dark-mode background streaks
        qml/components/StyledInput.qml
        qml/components/ToastMessage.qml
        qml/components/PlaceholderTab.qml   # drop-in stub for scaffolding a new tab
        qml/components/MiniGraphPlot.qml    # inline chat-bubble plot for AITab's plot_graph skill
        qml/components/SkillResultCard.qml  # inline chat-bubble result card for AITab's other skills
        qml/components/SnakeGame.qml        # secret game — see AITab.qml's checkSecretTrigger()
        qml/components/BossFight.qml        # secret boss fight — see AITab.qml's checkSecretTrigger()
        qml/Theme.qml
)


# Bundles the AI skills registry into the binary itself — desktop *and*
# Android, where there's no source tree on-device to read a plain file
# path from. This is what lets AITab load skillviewer.md's real content
# at runtime (qrc:/ai-skills/skillviewer.md) instead of the hand-kept
# mirror it used to carry in systemPrompt — see FileHelper::readTextFile
# and AITab.qml's loadSkillsPromptText() for the other half of this.
# PREFIX "/" + the FILES path itself (no BASE override) is what puts this
# at exactly qrc:/ai-skills/skillviewer.md rather than some CMake-derived
# path — see qt_add_resources' own docs on PREFIX/BASE/alias if this ever
# needs to move.
qt_add_resources(SmartCalc "ai_skills"
    PREFIX "/"
    FILES
        ai-skills/skillviewer.md
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
