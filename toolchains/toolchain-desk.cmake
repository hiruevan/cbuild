cmake_minimum_required(VERSION 3.13)

set(BUILD_NAME "CTAR")
set(PROJECT_TITLE "CNAME")

project(ce_project_desktop C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

set(SRC_DIR "${CMAKE_SOURCE_DIR}/CSRCDIR"
    CACHE PATH "Folder with the .c files"
)

set(CBUILD_LNX_DIR "lnx" CACHE STRING "Linux output subfolder")

if(WIN32)
    set(PLATFORM_OUTPUT_DIR "${CMAKE_SOURCE_DIR}/CBINDIR/win")
elseif(APPLE)
    set(PLATFORM_OUTPUT_DIR "${CMAKE_SOURCE_DIR}/CBINDIR/mac")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(PLATFORM_OUTPUT_DIR "${CMAKE_SOURCE_DIR}/CBINDIR/${CBUILD_LNX_DIR}")
else()
    message(FATAL_ERROR "Unsupported target platform: ${CMAKE_SYSTEM_NAME}")
endif()

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PLATFORM_OUTPUT_DIR}")

find_package(SDL2 REQUIRED)

add_library(ce_shim STATIC
    desk_shim/src/graphx.c
    desk_shim/src/keypadc.c
    desk_shim/src/fileioc.c
)

target_compile_definitions(ce_shim PRIVATE
    CE_WINDOW_TITLE="${PROJECT_TITLE}"
    CBUILD_APP_NAME="${BUILD_NAME}"
)

target_include_directories(ce_shim PUBLIC
    desk_shim/include
)

target_include_directories(ce_shim PRIVATE
    desk_shim/src
)

set(INCLUDE_DIR "${CMAKE_SOURCE_DIR}/CINCDIR"
    CACHE PATH "Folder with the project headers"
)

set(MAIN_SOURCE "${SRC_DIR}/CSRCFILES")
if(NOT EXISTS "${MAIN_SOURCE}")
    message(FATAL_ERROR "Entry file not found: ${MAIN_SOURCE}")
endif()

file(GLOB_RECURSE PROJECT_SOURCES CONFIGURE_DEPENDS "${SRC_DIR}/*.c")
list(APPEND PROJECT_SOURCES "${MAIN_SOURCE}")
list(REMOVE_DUPLICATES PROJECT_SOURCES)

if(WIN32 AND EXISTS "${CMAKE_SOURCE_DIR}/CRESOURCEDIR/icon.ico")
    enable_language(RC)
endif()

if(WIN32)
    add_executable(${BUILD_NAME} WIN32 ${PROJECT_SOURCES})
elseif(APPLE)
    add_executable(${BUILD_NAME} MACOSX_BUNDLE ${PROJECT_SOURCES})
else()
    add_executable(${BUILD_NAME} ${PROJECT_SOURCES})
endif()

target_link_libraries(${BUILD_NAME} PRIVATE ce_shim)

target_include_directories(${BUILD_NAME} PRIVATE
    "${SRC_DIR}"
    "${INCLUDE_DIR}"
    "${CMAKE_BINARY_DIR}"
)

if(WIN32)
    set_target_properties(${BUILD_NAME} PROPERTIES
        OUTPUT_NAME "${BUILD_NAME}"
        SUFFIX ".exe"
        RUNTIME_OUTPUT_DIRECTORY "${PLATFORM_OUTPUT_DIR}"
    )

    if(EXISTS "${CMAKE_SOURCE_DIR}/CRESOURCEDIR/icon.ico")
        file(WRITE "${CMAKE_BINARY_DIR}/app.rc"
            "IDI_ICON1 ICON \"${CMAKE_SOURCE_DIR}/CRESOURCEDIR/icon.ico\"\n"
        )

        target_sources(${BUILD_NAME} PRIVATE
            "${CMAKE_BINARY_DIR}/app.rc"
        )
    endif()

elseif(APPLE)
    set_target_properties(${BUILD_NAME} PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "${PROJECT_TITLE}"
        MACOSX_BUNDLE_GUI_IDENTIFIER "org.${BUILD_NAME}.game" # .app?
        MACOSX_BUNDLE_BUNDLE_VERSION "1.0.0"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0.0"
        OUTPUT_NAME "${BUILD_NAME}"
        RUNTIME_OUTPUT_DIRECTORY "${PLATFORM_OUTPUT_DIR}"
    )

elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set_target_properties(${BUILD_NAME} PROPERTIES
        OUTPUT_NAME "${BUILD_NAME}"
        SUFFIX ".elf"
        RUNTIME_OUTPUT_DIRECTORY "${PLATFORM_OUTPUT_DIR}"
    )
endif()

if(TARGET SDL2::SDL2)
    target_link_libraries(ce_shim PUBLIC SDL2::SDL2)
else()
    target_include_directories(ce_shim PUBLIC
        ${SDL2_INCLUDE_DIRS}
    )
    target_link_libraries(ce_shim PUBLIC
        ${SDL2_LIBRARIES}
    )
endif()

if(UNIX)
    target_link_libraries(ce_shim PUBLIC m)
endif()
