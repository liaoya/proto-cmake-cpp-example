cmake_minimum_required(VERSION 3.23)

project(protobuf_example CXX)

add_subdirectory(proto)

add_executable(my_app src/main.cpp)

target_link_libraries(my_app myproto)
