cmake_minimum_required(VERSION 3.23)

set(project_name myproto)
project(myproto LANGUAGES CXX)

file(GLOB PROTO_FILES "*.proto")
# message("${PROTO_FILES}")
add_library(${project_name} ${PROTO_FILES})
find_package(protobuf CONFIG REQUIRED)

protobuf_generate(TARGET ${project_name} LANGUAGE cpp)
target_include_directories(${project_name} INTERFACE ${CMAKE_CURRENT_BINARY_DIR})

target_link_libraries(${project_name}
    PUBLIC
        protobuf::libprotobuf
)
