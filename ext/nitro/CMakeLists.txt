cmake_minimum_required(VERSION 3.10)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

project(nitro VERSION 0.0.1)

add_library(${PROJECT_NAME} SHARED
    c_api.cpp
    rom.cpp
    armbin.cpp
    overlaybin.cpp
    headerbin.cpp
    blz.cpp
)

target_compile_features(${PROJECT_NAME} PUBLIC)
