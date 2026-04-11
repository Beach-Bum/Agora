cmake_minimum_required(VERSION 3.16)
project(AgoraUI LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# ── Paths ─────────────────────────────────────────────────────────
set(LOGOS_APP_BUNDLE     "/Applications/LogosApp.app" CACHE PATH "LogosApp bundle")
set(LOGOS_APP_FRAMEWORKS "${LOGOS_APP_BUNDLE}/Contents/Frameworks")
set(LOGOS_LIBLOGOS_ROOT  "$ENV{HOME}/logos-core-poc/logos-liblogos"    CACHE PATH "logos-liblogos root")
set(LOGOS_CPP_SDK_ROOT   "$ENV{HOME}/logos-core-poc/logos-cpp-sdk"     CACHE PATH "logos-cpp-sdk root")
set(LOGOS_APP_INTERFACES "$ENV{HOME}/logos-core-poc/logos-app-poc/interfaces" CACHE PATH "IComponent.h")

# ── Qt ────────────────────────────────────────────────────────────
set(CMAKE_PREFIX_PATH "/opt/homebrew/opt/qt@6")
find_package(Qt6 REQUIRED COMPONENTS Core Widgets Quick QuickWidgets Qml RemoteObjects Network)

# ── Register QML module so Qt can find components at runtime ──────
# Qt6: use qt_add_qml_module for proper module registration
qt_add_qml_module(agora_qml
    URI             Agora
    VERSION         1.0
    NO_PLUGIN                     # we embed in the dylib, not a separate qmldir plugin
    QML_FILES
        # Root
        src/AgoraRoot.qml
        # Components — each in its own file (required by Qt QML engine)
        src/components/AMButton.qml
        src/components/AMCard.qml
        src/components/AMFilterButton.qml
        src/components/AMHashRow.qml
        src/components/AMRepBar.qml
        src/components/AMSectionTitle.qml
        src/components/AMStatusBadge.qml
        src/components/AMTag.qml
        # Views
        src/views/BuyView.qml
        src/views/FeedView.qml
        src/views/MarketplaceView.qml
        src/views/SellView.qml
        src/views/WalletView.qml
    RESOURCES
        src/components/qmldir
        src/views/qmldir
)

# ── logos-cpp-generator ───────────────────────────────────────────
set(CPP_GENERATOR "$ENV{HOME}/logos-core-poc/build/cpp-generator/bin/logos-cpp-generator")
add_custom_target(run_cpp_generator_agora_ui
    COMMAND "${CPP_GENERATOR}"
            --metadata "${CMAKE_CURRENT_SOURCE_DIR}/metadata.json"
            --module-dir "${CMAKE_BINARY_DIR}/modules"
    WORKING_DIRECTORY "$ENV{HOME}/logos-core-poc"
    COMMENT "Running logos-cpp-generator for agora_ui"
    VERBATIM
)

# ── UI plugin ─────────────────────────────────────────────────────
add_library(agora_ui SHARED
    AgoraUIComponent.cpp
    AgoraUIComponent.h
    AgoraBridge.cpp
    AgoraBridge.h
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api.h
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api_client.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api_client.h
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api_consumer.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api_provider.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/token_manager.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/module_proxy.cpp
)

# Link the generated QML object library into the plugin
target_link_libraries(agora_ui PRIVATE agora_qml)
add_dependencies(agora_ui run_cpp_generator_agora_ui)

set_target_properties(agora_ui PROPERTIES PREFIX "")

target_link_libraries(agora_ui PRIVATE
    Qt6::Core Qt6::Widgets Qt6::Quick Qt6::QuickWidgets Qt6::Qml Qt6::RemoteObjects Qt6::Network
    "${LOGOS_APP_FRAMEWORKS}/liblogos_core.dylib"
)

target_include_directories(agora_ui PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${LOGOS_APP_INTERFACES}
    ${LOGOS_LIBLOGOS_ROOT}
    ${LOGOS_CPP_SDK_ROOT}/cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/generated
)

set_target_properties(agora_ui PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
    INSTALL_RPATH "@loader_path/../lib;@loader_path"
    BUILD_WITH_INSTALL_RPATH TRUE
)

add_custom_command(TARGET agora_ui POST_BUILD
    COMMAND install_name_tool -id "@rpath/agora_ui.dylib" $<TARGET_FILE:agora_ui>
    COMMENT "Fixing install name"
)

# ── Deploy target ─────────────────────────────────────────────────
add_custom_target(deploy
    COMMAND cp $<TARGET_FILE:agora_ui> "${LOGOS_APP_FRAMEWORKS}/agora_ui.dylib"
    COMMAND echo "✓ Deployed agora_ui.dylib"
    DEPENDS agora_ui
)
