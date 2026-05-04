cmake_minimum_required(VERSION 3.16)
project(ShaderRenderer VERSION 1.0 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)

# =========================
# GLFW
# =========================
FetchContent_Declare(glfw
    GIT_REPOSITORY https://github.com/glfw/glfw.git
    GIT_TAG 3.4
)
set(GLFW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(glfw)

# =========================
# GLM
# =========================
FetchContent_Declare(glm
    GIT_REPOSITORY https://github.com/g-truc/glm.git
    GIT_TAG 1.0.1
)
FetchContent_MakeAvailable(glm)

# =========================
# STB
# =========================
FetchContent_Declare(stb
    GIT_REPOSITORY https://github.com/nothings/stb.git
)
FetchContent_MakeAvailable(stb)

# =========================
# ImGui
# =========================
FetchContent_Declare(imgui
    GIT_REPOSITORY https://github.com/ocornut/imgui.git
    GIT_TAG v1.91.9
)
FetchContent_MakeAvailable(imgui)

# =========================
# GLAD
# =========================
FetchContent_Declare(glad
    GIT_REPOSITORY https://github.com/Dav1dde/glad.git
    GIT_TAG v2.0.8
    SOURCE_SUBDIR cmake
)
set(GLAD_PROFILE "core" CACHE STRING "" FORCE)
FetchContent_MakeAvailable(glad)
glad_add_library(glad_gl REPRODUCIBLE API gl:core=3.3)

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

target_include_directories(ShaderRenderer PRIVATE
    src
    include
    ${imgui_SOURCE_DIR}
    ${imgui_SOURCE_DIR}/backends
    ${stb_SOURCE_DIR}
)

target_compile_definitions(ShaderRenderer PRIVATE
    GLFW_INCLUDE_NONE
)

target_link_libraries(ShaderRenderer PRIVATE
    glfw
    glad_gl
    glm::glm
    OpenGL::GL
)

# =========================
# FONT DOWNLOAD (ROBUST FIX)
# =========================

set(FONTS_DIR ${CMAKE_CURRENT_SOURCE_DIR}/fonts)
file(MAKE_DIRECTORY ${FONTS_DIR})

set(NOTO_SANS "${FONTS_DIR}/NotoSans-Regular.ttf")
set(NOTO_SYMBOLS "${FONTS_DIR}/fa-solid-900.ttf")

function(download_file url output)
    if(EXISTS "${output}")
        message(STATUS "Font exists: ${output}")
        return()
    endif()

    set(tries 3)
    set(success FALSE)

    foreach(i RANGE 1 ${tries})
        message(STATUS "Downloading (${i}/${tries}): ${url}")

        file(DOWNLOAD
            "${url}"
            "${output}"
            SHOW_PROGRESS
            STATUS status
            TLS_VERIFY ON
        )

        list(GET status 0 code)

        if(code EQUAL 0)
            set(success TRUE)
            break()
        else()
            list(GET status 1 msg)
            message(WARNING "Attempt ${i} failed: ${msg}")
        endif()
    endforeach()

    if(NOT success)
        message(WARNING "Font failed but build continues: ${output}")
    endif()
endfunction()

# =========================
# FONT URLs (FIXED RAW LINKS)
# =========================
download_file(
    "https://raw.githubusercontent.com/openmaptiles/fonts/refs/heads/master/noto-sans/NotoSans-Regular.ttf"
    "${NOTO_SANS}"
)

download_file(
    "https://raw.githubusercontent.com/components/font-awesome/refs/heads/master/webfonts/fa-solid-900.ttf"
    "${NOTO_SYMBOLS}"
)

# =========================
# ASSETS COPY
# =========================
set(SHADERS_DIR ${CMAKE_CURRENT_SOURCE_DIR}/shaders)
set(IMAGES_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src/images)

add_custom_command(TARGET ShaderRenderer POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory $<TARGET_FILE_DIR:ShaderRenderer>/fonts
    COMMAND ${CMAKE_COMMAND} -E make_directory $<TARGET_FILE_DIR:ShaderRenderer>/shaders
    COMMAND ${CMAKE_COMMAND} -E make_directory $<TARGET_FILE_DIR:ShaderRenderer>/images

    COMMAND ${CMAKE_COMMAND} -E copy_directory ${FONTS_DIR} $<TARGET_FILE_DIR:ShaderRenderer>/fonts
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${SHADERS_DIR} $<TARGET_FILE_DIR:ShaderRenderer>/shaders
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${IMAGES_DIR} $<TARGET_FILE_DIR:ShaderRenderer>/images
)

set_target_properties(ShaderRenderer PROPERTIES
    VS_DEBUGGER_WORKING_DIRECTORY "$<TARGET_FILE_DIR:ShaderRenderer>"
)