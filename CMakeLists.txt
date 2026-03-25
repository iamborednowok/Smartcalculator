cmake_minimum_required(VERSION 3.16)
project(SmartCalc VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network Qml)
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

qt_add_qml_module(SmartCalc
    URI SmartCalc
    VERSION 1.0
    QML_FILES
        qml/main.qml
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
    RESOURCES
        qml/Theme.qml
)

set_target_properties(SmartCalc PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER com.smartcalc.app
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(SmartCalc PRIVATE
    Qt6::Quick
    Qt6::Network
    Qt6::Qml
)

# Android config
if(ANDROID)
    set_property(TARGET SmartCalc APPEND PROPERTY QT_ANDROID_PACKAGE_SOURCE_DIR
                 ${CMAKE_CURRENT_SOURCE_DIR}/android)
endif()
