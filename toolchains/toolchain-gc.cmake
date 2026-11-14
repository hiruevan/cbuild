cmake_minimum_required(VERSION 3.13)

set(BUILD_NAME "CTAR")
set(PROJECT_TITLE "CNAME")

project(ce_project_gc C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(SRC_DIR "${CMAKE_SOURCE_DIR}/CSRCDIR")
set(INCLUDE_DIR "${CMAKE_SOURCE_DIR}/CINCDIR")
set(BUILD_DIR "${CMAKE_SOURCE_DIR}/CBUILDDIR/gc")
set(OUTPUT_DIR "${CMAKE_SOURCE_DIR}/CBINDIR/gc")

set(MAIN_SOURCE "${SRC_DIR}/CSRCFILES")

set(INPUT_SOURCE "${BUILD_DIR}/input.c")
set(INPUT_HEADER "${BUILD_DIR}/input.h")

foreach(REQUIRED_FILE
    "${MAIN_SOURCE}"
    "${INPUT_SOURCE}"
    "${INPUT_HEADER}"
)
    if(NOT EXISTS "${REQUIRED_FILE}")
        message(FATAL_ERROR
            "Required file not found: ${REQUIRED_FILE}"
        )
    endif()
endforeach()

file(GLOB_RECURSE PROJECT_SOURCES
    CONFIGURE_DEPENDS
    "${SRC_DIR}/*.c"
)

list(APPEND PROJECT_SOURCES "${MAIN_SOURCE}")
list(REMOVE_DUPLICATES PROJECT_SOURCES)

add_library(ce_shim STATIC
    gc_shim/src/graphx.c
    gc_shim/src/keypadc.c
    gc_shim/src/fileioc.c
    gc_shim/src/sdl_compat.c
)

target_include_directories(ce_shim PUBLIC
    gc_shim/include
)

target_link_libraries(ce_shim PUBLIC
    ogc
    fat
    m
)

add_executable(${BUILD_NAME}
    ${PROJECT_SOURCES}
    "${INPUT_SOURCE}"
)

target_include_directories(${BUILD_NAME} PRIVATE
    "${SRC_DIR}"
    "${INCLUDE_DIR}"
    "${BUILD_DIR}"
    "${CMAKE_BINARY_DIR}"
)

target_link_libraries(${BUILD_NAME} PRIVATE
    ce_shim
)

set_target_properties(${BUILD_NAME} PROPERTIES
    OUTPUT_NAME "${BUILD_NAME}"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
)

find_program(ELF2DOL elf2dol HINTS "$ENV{DEVKITPRO}/tools/bin" REQUIRED)

add_custom_command(TARGET ${BUILD_NAME} POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OUTPUT_DIR}"
    COMMAND "${ELF2DOL}" "$<TARGET_FILE:${BUILD_NAME}>" "${OUTPUT_DIR}/${BUILD_NAME}.dol"
    COMMENT "Creating ${BUILD_NAME}.dol"
    VERBATIM
)