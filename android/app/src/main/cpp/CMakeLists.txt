cmake_minimum_required(VERSION 3.18.1)
project(iridiscope_mobile C CXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(SNIFFER "${CMAKE_CURRENT_SOURCE_DIR}/vendor/iridium-sniffer")
set(IRIDI   "${CMAKE_CURRENT_SOURCE_DIR}/vendor/iridiscope")
set(KISS    "${CMAKE_CURRENT_SOURCE_DIR}/vendor/kissfft")
set(OSMO    "${CMAKE_CURRENT_SOURCE_DIR}/vendor/osmo-ir77")

set(CORE_SOURCES
    ${SNIFFER}/burst_detect.c
    ${SNIFFER}/burst_downmix.c
    ${SNIFFER}/qpsk_demod.c
    ${SNIFFER}/fir_filter.c
    ${SNIFFER}/window_func.c
    ${SNIFFER}/simd_generic.c
    ${SNIFFER}/cJSON.c
    ${IRIDI}/iridium/engine_globals.c
    ${IRIDI}/iridium/pipeline_c.c
    ${CMAKE_CURRENT_SOURCE_DIR}/shim/fft_shim.c
    ${KISS}/kiss_fft.c
    ${OSMO}/ambe.c
    ${OSMO}/ecc.c
    ${OSMO}/frame.c
    ${OSMO}/math.c
    ${OSMO}/synth.c
    ${OSMO}/tables.c
    ${OSMO}/tone.c
)

if(ANDROID_ABI STREQUAL "arm64-v8a")
    list(APPEND CORE_SOURCES ${SNIFFER}/simd_neon.c)
elseif(ANDROID_ABI STREQUAL "x86_64")
    list(APPEND CORE_SOURCES ${SNIFFER}/simd_sse42.c ${SNIFFER}/simd_avx2.c)
    set_source_files_properties(${SNIFFER}/simd_sse42.c PROPERTIES
        COMPILE_OPTIONS "-msse4.2")
    set_source_files_properties(${SNIFFER}/simd_avx2.c PROPERTIES
        COMPILE_OPTIONS "-mavx2;-mfma")
else()
    # armeabi-v7a is not shipped; the scalar kernels are still safe.
    message(STATUS "No SIMD tier selected for ${ANDROID_ABI}")
endif()

set(APP_SOURCES
    ${IRIDI}/core/engine.cpp
    ${IRIDI}/core/file_source.cpp
    ${IRIDI}/parser/fec.cpp
    ${IRIDI}/parser/iridium_parser.cpp
    ${IRIDI}/messages/acars.cpp
    ${IRIDI}/messages/pager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/mobile/mobile_bridge.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/mobile/push_iq_source.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/mobile/voice_manager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/mobile/jni_feed.cpp
)

add_library(iridiscope SHARED ${CORE_SOURCES} ${APP_SOURCES})

target_include_directories(iridiscope PRIVATE
    ${SNIFFER}
    ${IRIDI}
    ${IRIDI}/iridium
    ${KISS}
    ${OSMO}
    ${CMAKE_CURRENT_SOURCE_DIR}/shim
    ${CMAKE_CURRENT_SOURCE_DIR}/mobile
)

target_compile_definitions(iridiscope PRIVATE
    _GNU_SOURCE
    ANDROID
)

target_compile_options(iridiscope PRIVATE
    -O3
    -ffast-math
    -fno-common
    -Wall
    -Wno-unused-parameter
    -Wno-unused-function
    -Wno-sign-compare
    -Wno-missing-field-initializers
)

find_library(LOG_LIB log)
target_link_libraries(iridiscope
    ${LOG_LIB}
    m
    dl
)

# Keep the compiler from stripping the JNI entry point.
set_target_properties(iridiscope PROPERTIES
    C_VISIBILITY_PRESET default
    CXX_VISIBILITY_PRESET default
    VISIBILITY_INLINES_HIDDEN OFF)
