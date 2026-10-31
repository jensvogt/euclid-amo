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

# The icons config.xml names for the installer and the maintenance tool. IFW resolves them relative
# to config.xml's own directory and will not follow a path out of it, so they are copied in beside
# the generated config.xml rather than committed there twice - one .ico, one .png, each with exactly
# one source in the tree. COPYONLY (not a plain file(COPY)) so that editing either source
# re-triggers configure instead of leaving a stale icon in the next installer build.
#
# Extension-less <InstallerApplicationIcon>euclid-amo</InstallerApplicationIcon> means IFW picks the
# .ico on Windows and the .png on Linux, which is why both are staged on every platform.
configure_file("${CMAKE_SOURCE_DIR}/dist/win32/euclid-amo.ico"
        "${CMAKE_SOURCE_DIR}/dist/win32/installer/config/euclid-amo.ico" COPYONLY)
configure_file("${CMAKE_SOURCE_DIR}/dist/branding/euclid-cardio-64.png"
        "${CMAKE_SOURCE_DIR}/dist/win32/installer/config/euclid-amo.png" COPYONLY)

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
set_source_files_properties(qml/components/RefreshIntervals.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

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
        qml/components/MainMenu.qml
        qml/components/ServerDashboardDialog.qml
        qml/components/DashboardGrid.qml
        qml/components/PanelFrame.qml
        qml/components/PanelEditor.qml
        qml/components/MetricPicker.qml
        qml/components/DashboardDialog.qml
        qml/components/StatusBar.qml
        qml/components/DetachedDashboard.qml
        qml/components/ServerSaveDialog.qml
        qml/components/DashboardCheckList.qml
        qml/components/TimeRangeDialog.qml
        qml/components/DateTimePicker.qml
        qml/components/StatusStrip.qml
        qml/components/AboutDialog.qml
        qml/components/RefreshIntervals.qml
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

# Windows application icon. qt_add_executable() produces an .exe with no icon resource, which
# Windows renders as the generic application icon - including on the desktop and Start menu
# shortcuts the IFW installer creates, because installscript.qs points their iconPath at the .exe.
# Compiling the .rc in gives all of those the real mark at once, with no installer-side change.
#
# enable_language(RC) is explicit rather than relying on it coming along with C/CXX: project()
# above enables only those two, and a .rc in the source list of a target whose RC language was
# never enabled is silently ignored by some generators rather than failing the build - which would
# look exactly like success right up until someone looked at the installed shortcut.
if (WIN32)
    enable_language(RC)
    target_sources(euclid-amo PRIVATE dist/win32/euclid-amo.rc)
endif ()

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

# Puts Qt's DLLs, plugins and QML modules in the build directory, so the build tree runs as-is.
#
# Needed because of an asymmetry that is easy to trip over: the static Qt this project releases
# from is configured -release only (see build-release.yml), so there are no static debug libraries
# and a Debug build necessarily resolves to the *shared* Qt instead. That binary then wants
# Qt6Cored.dll, the "windows" platform plugin and QtQuick's own QML modules at load time. Started
# from an IDE or from Explorer, none of them are findable: the loader gives up before main() with
# no dialog and no output, exit code 127, which reads as "it just doesn't start".
#
# Guarded on Qt being shared rather than on the build type, because that is the actual condition.
# The release CI build links Qt statically, has nothing to copy, and must not grow a deploy step -
# which is what build-release.yml already says it does not need.
if (WIN32 AND QT6_IS_SHARED_LIBS_BUILD AND TARGET Qt6::windeployqt)
    add_custom_command(TARGET euclid-amo POST_BUILD
            COMMAND Qt6::windeployqt
            # The QML modules cannot be read off the binary: the app's own QML is baked into it as
            # a resource, so windeployqt is pointed at the sources to find what they import.
            --qmldir "${CMAKE_SOURCE_DIR}/qml"
            --no-translations
            # The debug CRT is not redistributable and comes with the compiler that just built
            # this, so it is already resolvable wherever a build happened.
            --no-compiler-runtime
            "$<TARGET_FILE:euclid-amo>"
            COMMENT "Deploying the Qt runtime beside euclid-amo.exe"
            VERBATIM)
endif ()
