cmake_minimum_required(VERSION 3.23)

# Declare the project with the given name "protobuf_example" and specify the language as C++.
project(protobuf_example CXX)

add_subdirectory(proto)

add_executable(my_app src/main.cpp)

target_link_libraries(my_app myproto)
