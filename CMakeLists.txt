cmake_minimum_required(VERSION 3.16)
project(ShaderRenderer VERSION 1.0 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# =========================
# FetchContent
# =========================
include(FetchContent)

# --- GLFW ---
FetchContent_Declare(
    glfw
    GIT_REPOSITORY https://github.com/glfw/glfw.git
    GIT_TAG        3.4
)
set(GLFW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(glfw)

# --- GLM ---
FetchContent_Declare(
    glm
    GIT_REPOSITORY https://github.com/g-truc/glm.git
    GIT_TAG        1.0.1
)
FetchContent_MakeAvailable(glm)

# --- STB (NO VERSION TAG — FIXED) ---
FetchContent_Declare(
    stb
    GIT_REPOSITORY https://github.com/nothings/stb.git
)
FetchContent_MakeAvailable(stb)

# --- ImGui ---
FetchContent_Declare(
    imgui
    GIT_REPOSITORY https://github.com/ocornut/imgui.git
    GIT_TAG        v1.91.9
)
FetchContent_MakeAvailable(imgui)

# --- GLAD 2 ---
FetchContent_Declare(
    glad
    GIT_REPOSITORY https://github.com/Dav1dde/glad.git
    GIT_TAG        v2.0.8
    SOURCE_SUBDIR  cmake
)
set(GLAD_PROFILE "core" CACHE STRING "" FORCE)
FetchContent_MakeAvailable(glad)

glad_add_library(glad_gl REPRODUCIBLE API gl:core=4.6)

# =========================
# OpenGL
# =========================
find_package(OpenGL REQUIRED)

# =========================
# ImGui sources
# =========================
set(IMGUI_SOURCES
    ${imgui_SOURCE_DIR}/imgui.cpp
    ${imgui_SOURCE_DIR}/imgui_demo.cpp
    ${imgui_SOURCE_DIR}/imgui_draw.cpp
    ${imgui_SOURCE_DIR}/imgui_tables.cpp
    ${imgui_SOURCE_DIR}/imgui_widgets.cpp
    ${imgui_SOURCE_DIR}/backends/imgui_impl_glfw.cpp
    ${imgui_SOURCE_DIR}/backends/imgui_impl_opengl3.cpp
)

# =========================
# Executable
# =========================
add_executable(ShaderRenderer
    src/main.cpp
    src/app.cpp
    src/editor.cpp
    src/shader.cpp
    ${IMGUI_SOURCES}
)

# =========================
# Includes
# =========================
target_include_directories(ShaderRenderer PRIVATE
    src
    include

    # ImGui
    ${imgui_SOURCE_DIR}
    ${imgui_SOURCE_DIR}/backends

    # STB
    ${stb_SOURCE_DIR}

    # GLAD
    $<TARGET_PROPERTY:glad_gl,INTERFACE_INCLUDE_DIRECTORIES>
)

# =========================
# DEFINES
# =========================
target_compile_definitions(ShaderRenderer PRIVATE
    GLFW_INCLUDE_NONE
    IMGUI_IMPL_OPENGL_LOADER_GLAD
)

# =========================
# LINK LIBRARIES
# =========================
target_link_libraries(ShaderRenderer PRIVATE
    glfw
    glad_gl
    glm::glm
    OpenGL::GL
    opengl32
)

# =========================
# ASSETS (FIXED - NO $<CONFIG> IN file())
# =========================

set(SHADER_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/shaders)
set(IMAGE_SRC_DIR  ${CMAKE_CURRENT_SOURCE_DIR}/src/images)

# Use generator expression ONLY in POST_BUILD (correct place)
add_custom_command(TARGET ShaderRenderer POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
        $<TARGET_FILE_DIR:ShaderRenderer>/shaders
    COMMAND ${CMAKE_COMMAND} -E make_directory
        $<TARGET_FILE_DIR:ShaderRenderer>/images

    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${SHADER_SRC_DIR}
        $<TARGET_FILE_DIR:ShaderRenderer>/shaders

    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${IMAGE_SRC_DIR}
        $<TARGET_FILE_DIR:ShaderRenderer>/images
)