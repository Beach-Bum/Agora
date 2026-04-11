cmake_minimum_required(VERSION 3.16)
project(AgoraModule LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# ── Paths ─────────────────────────────────────────────────────────
set(LOGOS_APP_BUNDLE    "/Applications/LogosApp.app" CACHE PATH "Installed LogosApp bundle")
set(LOGOS_APP_FRAMEWORKS "${LOGOS_APP_BUNDLE}/Contents/Frameworks")
set(LOGOS_LIBLOGOS_ROOT "$ENV{HOME}/logos-core-poc/logos-liblogos" CACHE PATH "logos-liblogos root")
set(LOGOS_CPP_SDK_ROOT  "$ENV{HOME}/logos-core-poc/logos-cpp-sdk"  CACHE PATH "logos-cpp-sdk root")

# ── Qt ────────────────────────────────────────────────────────────
set(CMAKE_PREFIX_PATH "/opt/homebrew/opt/qt@6")
find_package(Qt6 REQUIRED COMPONENTS Core Network RemoteObjects)

# ── logos-cpp-generator ───────────────────────────────────────────
set(CPP_GENERATOR "$ENV{HOME}/logos-core-poc/build/cpp-generator/bin/logos-cpp-generator")
add_custom_target(run_cpp_generator_agora
    COMMAND "${CPP_GENERATOR}"
            --metadata "${CMAKE_CURRENT_SOURCE_DIR}/metadata.json"
            --module-dir "${CMAKE_BINARY_DIR}/modules"
    WORKING_DIRECTORY "$ENV{HOME}/logos-core-poc"
    COMMENT "Running logos-cpp-generator for agora_module"
    VERBATIM
)

# ── Backend plugin ────────────────────────────────────────────────
add_library(agora_module_plugin SHARED
    agora_module_plugin.cpp
    agora_module_plugin.h
    src/AgoraCore.cpp
    src/AgoraCore.h
    src/DaemonAIService.cpp
    src/DaemonAIService.h
    src/MessagingService.h
    src/BlockchainService.h
    src/StorageService.h
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api_client.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api_consumer.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api_provider.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/token_manager.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/module_proxy.cpp
)

set_target_properties(agora_module_plugin PROPERTIES PREFIX "")
add_dependencies(agora_module_plugin run_cpp_generator_agora)

target_link_libraries(agora_module_plugin PRIVATE
    Qt6::Core Qt6::Network Qt6::RemoteObjects
    "${LOGOS_APP_FRAMEWORKS}/liblogos_core.dylib"
)

target_include_directories(agora_module_plugin PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${LOGOS_LIBLOGOS_ROOT}
    ${LOGOS_CPP_SDK_ROOT}/cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/generated
)

set_target_properties(agora_module_plugin PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
    INSTALL_RPATH "@loader_path/../lib;@loader_path"
    BUILD_WITH_INSTALL_RPATH TRUE
)

add_custom_command(TARGET agora_module_plugin POST_BUILD
    COMMAND install_name_tool -id "@rpath/agora_module_plugin.dylib"
        $<TARGET_FILE:agora_module_plugin>
    COMMENT "Fixing install name"
)

add_custom_target(deploy
    COMMAND cp $<TARGET_FILE:agora_module_plugin>
               "${LOGOS_APP_FRAMEWORKS}/agora_module_plugin.dylib"
    COMMAND echo "✓ Deployed agora_module_plugin.dylib"
    DEPENDS agora_module_plugin
)
