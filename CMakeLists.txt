cmake_minimum_required(VERSION 3.16)
project(ShaderRenderer VERSION 1.0 LANGUAGES CXX C)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find OpenGL
find_package(OpenGL REQUIRED)
# ImGui sources
set(IMGUI_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/imgui/imgui/imgui.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/imgui/imgui/imgui_demo.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/imgui/imgui/imgui_draw.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/imgui/imgui/imgui_tables.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/imgui/imgui/imgui_widgets.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/imgui/backends/imgui_impl_glfw.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/imgui/backends/imgui_impl_opengl3.cpp
)

# Main executable
add_executable(ShaderRenderer
    src/main.cpp
    src/app.cpp
    src/editor.cpp
    src/shader.cpp
    ${IMGUI_SOURCES}
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/glad/src/gl.c
)

target_include_directories(ShaderRenderer PRIVATE
    src
    include
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/imgui
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/imgui/imgui
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/imgui/backends
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/glfw/include
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/glad/include
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/glm
)

target_compile_definitions(ShaderRenderer PRIVATE GLFW_INCLUDE_NONE IMGUI_IMPL_OPENGL_LOADER_CUSTOM)

target_link_libraries(ShaderRenderer PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/glfw/lib/glfw3.lib
    OpenGL::GL
    opengl32
)

# Copy shaders directory to output
file(COPY shaders DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

