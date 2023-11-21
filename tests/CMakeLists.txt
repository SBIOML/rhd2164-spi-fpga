cmake_minimum_required(VERSION 3.14)

project(rhd_spi)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)

FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/03597a01ee50ed33e9dfd640b249b4be3799d395.zip
)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

# Declare library
add_library(rhd ../c/rhd.c)

# Add executable test
add_executable(
    rhd_test
    rhd_test.cpp
)
target_link_libraries(
    rhd_test
    GTest::gtest_main
    rhd
)
include_directories(
    ../c    
)

enable_testing()
include(GoogleTest)
gtest_discover_tests(rhd_test)