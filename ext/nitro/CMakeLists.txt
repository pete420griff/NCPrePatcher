cmake_minimum_required(VERSION 3.10)
project(Nitro LANGUAGES CXX)

add_library(Nitro SHARED
    c_api.cpp
    rom.cpp
    armbin.cpp
    overlaybin.cpp
    headerbin.cpp
    blz.cpp
)

target_compile_features(Nitro PUBLIC cxx_std_20)
