cmake_minimum_required(VERSION 3.16)

file(READ "${CMAKE_SOURCE_DIR}/version.txt" VERSION_STRING_RAW)
string(STRIP "${VERSION_STRING_RAW}" VERSION_STRING)

project(euclid-amo VERSION ${VERSION_STRING})

string(TIMESTAMP RELEASE_DATE "%Y-%m-%d %H:%M:%S")

# Resolves the Qt Installer Framework config/package XML templates (dist/win32/installer/**/*.xml.in)
# against the version above and the current timestamp. Only meaningful for the Windows installer
# build, but run on every platform and every configure so the templates cannot rot unnoticed on the
# two platforms nobody builds the installer from; the generated .xml files are gitignored.
file(READ "${CMAKE_SOURCE_DIR}/dist/win32/installer/config/config.xml.in" _CONFIG_XML)
string(REPLACE "@VERSION_STRING@" "${VERSION_STRING}" _CONFIG_XML "${_CONFIG_XML}")
file(WRITE "${CMAKE_SOURCE_DIR}/dist/win32/installer/config/config.xml" "${_CONFIG_XML}")

file(READ "${CMAKE_SOURCE_DIR}/dist/win32/installer/packages/de.jensvogt.euclidamo/meta/package.xml.in" _PACKAGE_XML)
string(REPLACE "@VERSION_STRING@" "${VERSION_STRING}" _PACKAGE_XML "${_PACKAGE_XML}")
string(REPLACE "@RELEASE_DATE@" "${RELEASE_DATE}" _PACKAGE_XML "${_PACKAGE_XML}")
file(WRITE "${CMAKE_SOURCE_DIR}/dist/win32/installer/packages/de.jensvogt.euclidamo/meta/package.xml" "${_PACKAGE_XML}")

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# The same statically linked Qt 6 build euclid-rui uses; override with -DCMAKE_PREFIX_PATH=...
if (NOT DEFINED CMAKE_PREFIX_PATH)
    set(CMAKE_PREFIX_PATH "/opt/qt-static")
endif ()

set(BUILD_SHARED_LIBS OFF)

find_package(Qt6 COMPONENTS
        Core
        Gui
        Network
        Qml
        Quick
        QuickControls2
        REQUIRED)

qt_standard_project_setup(REQUIRES 6.4)

qt_policy(SET QTP0004 NEW)

qt_add_executable(euclid-amo main.cpp
        AppSettings.h AppSettings.cpp
        client/EuclidBaseClient.h client/EuclidBaseClient.cpp
        client/RequestSigner.h client/RequestSigner.cpp
        client/EmoClient.h client/EmoClient.cpp
        model/DashboardStore.h model/DashboardStore.cpp
)

set_source_files_properties(qml/components/DateFormat.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/components/SizeFormat.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/components/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/components/MetricFormat.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(euclid-amo
        URI EuclidAmo
        VERSION 1.0
        QML_FILES
        qml/Main.qml
        qml/LoginDialog.qml
        qml/components/Theme.qml
        qml/components/DateFormat.qml
        qml/components/SizeFormat.qml
        qml/components/MetricFormat.qml
        qml/components/LineChart.qml
        qml/components/BarChart.qml
        qml/components/StatPanel.qml
        qml/components/GaugePanel.qml
        qml/components/DashboardGrid.qml
        qml/components/PanelFrame.qml
        qml/components/PanelEditor.qml
        qml/components/TimeRangeBar.qml
        qml/components/SettingsDialog.qml
        qml/components/ToggleSwitch.qml
)

# Build against the Windows GUI subsystem rather than the console one. qt_add_executable() does
# NOT do this for you - it forwards to a plain add_executable() without WIN32 - so without this the
# linker produces a console application and Windows opens a CMD window behind the app every time it
# starts, including from the installer's shortcuts. Ignored on Linux and macOS.
#
# This also brings in Qt's entry point shim: Qt6::Core only pulls in Qt6::EntryPointPrivate (which
# provides WinMain and calls main) when WIN32_EXECUTABLE is set, so the two have to be turned on
# together, and are.
set_target_properties(euclid-amo PROPERTIES WIN32_EXECUTABLE TRUE)

target_compile_definitions(euclid-amo PRIVATE APP_VERSION="${VERSION_STRING}" BUILD_DATE="${RELEASE_DATE}")

target_link_libraries(euclid-amo
        PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Network
        Qt6::Qml
        Qt6::Quick
        Qt6::QuickControls2
)
