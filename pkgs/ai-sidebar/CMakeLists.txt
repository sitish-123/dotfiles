cmake_minimum_required(VERSION 3.16)
project(ai-sidebar VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 WebEngineQuick Gui Network)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(ai-sidebar main.cpp)
qt_add_qml_module(ai-sidebar
    URI aisidebar
    VERSION 1.0
    QML_FILES Main.qml
)
target_link_libraries(ai-sidebar PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::WebEngineQuick
    Qt6::Gui
    Qt6::Network
)

install(TARGETS ai-sidebar RUNTIME DESTINATION bin)
