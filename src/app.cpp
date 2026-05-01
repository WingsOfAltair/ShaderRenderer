#include "app.h"
#include <GLFW/glfw3.h>
#include <glad/gl.h>
#include <imgui.h>
#include <imgui_impl_glfw.h>
#include <imgui_impl_opengl3.h>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <map>
#include <iostream>
#include <cstring>
#include <cmath>
#include <algorithm>
#include <cctype>
#ifdef _WIN32
#include <windows.h>
#endif
#define STB_IMAGE_IMPLEMENTATION
#include <stb_image.h>

// Default vertex shader
const char* App::defaultVertexShader = R"(
#version 330 core
layout(location = 0) in vec2 aPos;
void main() {
    gl_Position = vec4(aPos, 0.0, 1.0);
}
)";

// Default fragment shader
const char* App::defaultFragmentShader = R"(
#version 330 core
out vec4 FragColor;
uniform float uTime;
uniform vec2 uResolution;
uniform vec2 uMouse;

void main() {
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 pos = uv * 2.0 - 1.0;
    float radius = length(pos);
    vec3 color = 0.5 + 0.5 * cos(vec3(0.0, 2.0, 4.0) + pos.xyx * 3.0 + uTime);
    color *= 1.0 - smoothstep(0.5, 0.9, radius);
    FragColor = vec4(color, 0.6);
}
)";

// Test fragment shader
const char* App::testFragmentShader = R"(
#version 330 core
out vec4 FragColor;
uniform float uTime;
uniform vec2 uResolution;
uniform vec2 uMouse;

void main() {
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec3 color = vec3(uv, 0.5 + 0.5 * sin(uTime * 2.0));
    color = pow(color, vec3(0.45));
    FragColor = vec4(color, 0.6);
}
)";

// Default compute shader
const char* App::defaultComputeShader = R"(
#version 430 core
layout(local_size_x = 16, local_size_y = 16) in;
layout(rgba32f, binding = 0) uniform image2D img;
uniform float uTime;
uniform vec2 uResolution;

void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (pixel.x >= int(uResolution.x) || pixel.y >= int(uResolution.y)) {
        return;
    }
    vec2 uv = vec2(pixel) / uResolution;
    vec3 color = 0.5 + 0.5 * cos(uTime + uv.xyx * 6.2831853 + vec3(0.0, 2.0, 4.0));
    imageStore(img, pixel, vec4(color, 1.0));
}
)";

const char* App::defaultDisplayVertexShader = R"(
#version 330 core
layout(location = 0) in vec2 aPos;
layout(location = 1) in vec2 aTexCoord;

out vec2 vTexCoord;

void main() {
    vTexCoord = aTexCoord;
    gl_Position = vec4(aPos, 0.0, 1.0);
}
)";

const char* App::defaultDisplayFragmentShader = R"(
#version 330 core
out vec4 FragColor;
in vec2 vTexCoord;
uniform sampler2D uTexture;

void main() {
    FragColor = texture(uTexture, vTexCoord);
}
)";

void App::createFBO(GLuint& fbo, GLuint& tex)
{
    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);

    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F,
        windowWidth, windowHeight, 0,
        GL_RGBA, GL_FLOAT, nullptr);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    glFramebufferTexture2D(GL_FRAMEBUFFER,
        GL_COLOR_ATTACHMENT0,
        GL_TEXTURE_2D, tex, 0);

    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        std::cerr << "FBO incomplete!\n";

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void App::destroyFBO(GLuint& fbo, GLuint& tex)
{
    if (tex) glDeleteTextures(1, &tex);
    if (fbo) glDeleteFramebuffers(1, &fbo);
    tex = 0;
    fbo = 0;
}

App::App()
    : window(nullptr), windowWidth(1280), windowHeight(720),
      shaderValid(false), computeValid(false), useComputeShader(false),
      time(0.0f),
      showHelp(false), showSavedShaders(true), showVertexEditor(true), showFragmentEditor(true), showComputeEditor(true),
      hintTimer(0.0f), showHint(false),
      showCompileErrorPopup(false), compileErrorPopupMessage(""), compileErrorPopupTimer(0.0f),
      VAO(0), VBO(0), computeTexture(0), selectedPreset(""), newPresetName(""), errorTexture(0)
{
}

App::~App()
{
    shutdown();
}

void App::loadLogoTexture()
{
    if (logoLoaded) return;

    std::string path = (getExecutableDirectory() / "images/plancksoft_b_t.png").string();

    int width, height, channels;
    stbi_set_flip_vertically_on_load(true);

    unsigned char* data = stbi_load(path.c_str(), &width, &height, &channels, 4);
    if (!data) {
        std::cerr << "Failed to load image: " << path << std::endl;
        return;
    }

    glGenTextures(1, &logoTexture);
    glBindTexture(GL_TEXTURE_2D, logoTexture);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,
        width, height, 0,
        GL_RGBA, GL_UNSIGNED_BYTE, data);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    stbi_image_free(data);

    logoLoaded = true;
}

void App::createErrorTexture()
{
    if (errorTexture) return;

    const int size = 256;
    std::vector<unsigned char> data(size * size * 4);

    for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {

            int i = (y * size + x) * 4;

            bool checker = ((x / 32) % 2) ^ ((y / 32) % 2);

            if (checker) {
                // dark background
                data[i + 0] = 30;
                data[i + 1] = 0;
                data[i + 2] = 0;
            } else {
                // red error tint
                data[i + 0] = 200;
                data[i + 1] = 30;
                data[i + 2] = 30;
            }

            data[i + 3] = 255;
        }
    }

    glGenTextures(1, &errorTexture);
    glBindTexture(GL_TEXTURE_2D, errorTexture);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8,
        size, size, 0,
        GL_RGBA, GL_UNSIGNED_BYTE,
        data.data());

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

    glBindTexture(GL_TEXTURE_2D, 0);
}

bool App::init(int width, int height, const char* title)
{
    windowWidth = width;
    windowHeight = height;

    // Initialize GLFW
    if (!glfwInit()) {
        std::cerr << "Failed to initialize GLFW" << std::endl;
        return false;
    }

    // Configure GLFW
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
#ifdef __APPLE__
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#endif

    // Create window
    window = glfwCreateWindow(width, height, title, nullptr, nullptr);
    if (!window) {
        std::cerr << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return false;
    }
    glfwMakeContextCurrent(window);

    if (!gladLoadGL(glfwGetProcAddress)) {
        std::cerr << "Failed to initialize OpenGL loader" << std::endl;
        glfwDestroyWindow(window);
        glfwTerminate();
        return false;
    }

    glfwSetFramebufferSizeCallback(window, [](GLFWwindow* w, int ww, int hh)
    {
        auto* app = static_cast<App*>(glfwGetWindowUserPointer(w));

        app->windowWidth = ww;
        app->windowHeight = hh;

        glViewport(0, 0, ww, hh);

        app->destroyFBO(app->backgroundFBO, app->backgroundTex);
        app->destroyFBO(app->shaderFBO, app->shaderTex);

        app->createFBO(app->backgroundFBO, app->backgroundTex);
        app->createFBO(app->shaderFBO, app->shaderTex);

        app->destroyComputeTexture();
        app->createComputeTexture(ww, hh);
    });

    glfwSetWindowUserPointer(window, this);

    glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_DEBUG_OUTPUT);
    glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);

    glDebugMessageCallback([](GLenum source, GLenum type, GLuint id,
                            GLenum severity, GLsizei length,
                            const GLchar* message, const void* userParam)
    {
        std::cerr << "GL DEBUG: " << message << std::endl;
    }, nullptr);

    // Initialize ImGui
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;

    ImGui::StyleColorsDark();
    ImGui_ImplGlfw_InitForOpenGL(window, true);
    ImGui_ImplOpenGL3_Init("#version 430");

    // Set default shader code
    vertexCode = defaultVertexShader;
    fragmentCode = defaultFragmentShader;
    computeCode = defaultComputeShader;

    // Compile initial shaders
    compileShader();
    displayShader.compile(defaultDisplayVertexShader, defaultDisplayFragmentShader, compileError);
    std::cout << "Display shader compile: " << compileError << std::endl;

    // Create fullscreen quad and compute resources
    if (VAO) glDeleteVertexArrays(1, &VAO);
    if (VBO) glDeleteBuffers(1, &VBO);
    VAO = 0;
    VBO = 0;

    updateBuffers();
    loadLogoTexture();
    createErrorTexture();

    createFBO(backgroundFBO, backgroundTex);
    createFBO(shaderFBO, shaderTex);

    createComputeTexture(windowWidth, windowHeight);
    compileComputeShader();

    return true;
}

void App::run()
{
    while (!glfwWindowShouldClose(window))
{
    glfwPollEvents();

    if (glfwGetKey(window, GLFW_KEY_F5) == GLFW_PRESS)
    {
        compileShader();
        showHint = true;
        hintTimer = 0.0f;
    }

    time += 0.016f;

    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplGlfw_NewFrame();
    ImGui::NewFrame();

    renderUI();

    renderScene();   

    ImGui::Render();
    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());

    glfwSwapBuffers(window);
}
}

void App::shutdown()
{
    if (glIsVertexArray(VAO)) glDeleteVertexArrays(1, &VAO);
    if (glIsBuffer(VBO)) glDeleteBuffers(1, &VBO);
    destroyComputeTexture();

    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();

    if (window) {
        glfwDestroyWindow(window);
        window = nullptr;
    }
    glfwTerminate();
}

void App::renderUI()
{
    hintTimer += 0.016f;
    if (hintTimer > 10.0f) {
        showHint = false;
    }

    // Main menu bar
    if (ImGui::BeginMainMenuBar()) {
        if (ImGui::BeginMenu("Shader")) {
            if (ImGui::MenuItem("Reload (F5)", "F5")) {
                compileShader();
                showHint = true;
                hintTimer = 0.0f;
            }
            if (ImGui::MenuItem("Load test shader")) {
                fragmentCode = testFragmentShader;
                compileShader();
                showHint = true;
                hintTimer = 0.0f;
            }
            if (ImGui::MenuItem("Reset to default")) {
                vertexCode = defaultVertexShader;
                fragmentCode = defaultFragmentShader;
                compileShader();
                showHint = true;
                hintTimer = 0.0f;
            }
            ImGui::Separator();
            if (ImGui::MenuItem("Exit", "Alt+F4")) {
                glfwSetWindowShouldClose(window, true);
            }
            ImGui::EndMenu();
        }
        if (ImGui::BeginMenu("View")) {
            ImGui::MenuItem("Help", nullptr, &showHelp);
            ImGui::MenuItem("Vertex Shader", nullptr, &showVertexEditor);
            ImGui::MenuItem("Fragment Shader", nullptr, &showFragmentEditor);
            ImGui::MenuItem("Compute Shader", nullptr, &showComputeEditor);
            ImGui::MenuItem("Saved Shaders", nullptr, &showSavedShaders);
            ImGui::EndMenu();
        }
        ImGui::EndMainMenuBar();
    }

        // Compile error popup (shows for 5 seconds, allows copying)
    if (showCompileErrorPopup) {
        compileErrorPopupTimer += 0.016f;

        if (compileErrorPopupTimer >= 10.0f) {
            showCompileErrorPopup = false;
            compileErrorPopupTimer = 0.0f;
        }
    }

    // Hint popup
    if (showHint) {
        ImGui::SetNextWindowPos(ImVec2(10, 60), ImGuiCond_Always);
        ImGui::Begin("Hint", nullptr, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoInputs | ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoResize);
        ImGui::TextColored(ImVec4(0.0f, 1.0f, 0.0f, 1.0f), "%s", hintMessage.c_str());
        ImGui::End();
    }

    // Compile error popup
    if (showCompileErrorPopup) {
        ImGui::SetNextWindowPos(
            ImVec2(ImGui::GetIO().DisplaySize.x * 0.5f,
                ImGui::GetIO().DisplaySize.y * 0.5f),
            ImGuiCond_FirstUseEver
        );

        ImGui::SetNextWindowSize(ImVec2(500, 300), ImGuiCond_FirstUseEver);

        if (ImGui::Begin("Shader Compilation Error",
                        &showCompileErrorPopup,
                        ImGuiWindowFlags_None)) {

            loadLogoTexture();
            ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f),
                            "Compilation failed. The popup will close in %.0f seconds",
                            10.0f - compileErrorPopupTimer);

            ImGui::Separator();
            ImGui::TextWrapped("%s", compileErrorPopupMessage.c_str());

            ImGui::Separator();
            if (ImGui::Button("Copy to Clipboard", ImVec2(-1, 0))) {
                ImGui::SetClipboardText(compileErrorPopupMessage.c_str());
            }

            if (ImGui::Button("Close", ImVec2(-1, 0))) {
                showCompileErrorPopup = false;
                compileErrorPopupTimer = 0.0f;
            }
        }
        ImGui::End();
    }

    // Help window
    if (showHelp) {
        ImGui::SetNextWindowPos(ImVec2(10, 60), ImGuiCond_Always);
        ImGui::Begin("Help & Controls", &showHelp, ImGuiWindowFlags_NoCollapse);
        ImGui::TextColored(ImVec4(1.0f, 1.0f, 0.0f, 1.0f), "Controls:");
        ImGui::BulletText("F5 - Reload shader");
        ImGui::BulletText("Click in editor to edit code");
        ImGui::BulletText("Scroll to scroll in editor");
        ImGui::Separator();
        ImGui::TextColored(ImVec4(1.0f, 1.0f, 0.0f, 1.0f), "Built-in uniforms:");
        ImGui::BulletText("uTime - Time in seconds");
        ImGui::BulletText("uResolution - Window resolution");
        ImGui::BulletText("uMouse - Mouse position (0,0 = bottom-left)");
        ImGui::Separator();
        ImGui::TextColored(ImVec4(0.0f, 1.0f, 0.0f, 1.0f), "Tip:");
        ImGui::TextWrapped("Edit the fragment shader and press F5 to see changes instantly. The shader renders on a fullscreen quad. Use the Compute Shader panel to render into a texture when enabled.");
        ImGui::End();
    }

    renderSavedShadersWindow();

    if (showVertexEditor) {
        ImGui::SetNextWindowPos(ImVec2(10, 60), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(350, 350), ImGuiCond_FirstUseEver);
        ImGui::Begin("Vertex Shader", &showVertexEditor, ImGuiWindowFlags_None);
        ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), "Vertex Shader");
        ImGui::Separator();
        
        static char vertexBuf[8192] = "";
        strncpy(vertexBuf, vertexCode.c_str(), sizeof(vertexBuf) - 1);
        vertexBuf[sizeof(vertexBuf) - 1] = '\0';
        ImGui::InputTextMultiline("##vertex", vertexBuf, IM_ARRAYSIZE(vertexBuf), ImVec2(-1, -1), ImGuiInputTextFlags_None);
        vertexCode = vertexBuf;

        if (ImGui::Button("Compile (F5)", ImVec2(-1, 0))) {
            compileShader();
            showHint = true;
            hintTimer = 0.0f;
        }
        ImGui::SameLine();
        if (ImGui::Button("Reset", ImVec2(-1, 0))) {
            vertexCode = defaultVertexShader;
            strncpy(vertexBuf, defaultVertexShader, sizeof(vertexBuf) - 1);
            vertexBuf[sizeof(vertexBuf) - 1] = '\0';
            compileShader();
        }

        if (!compileError.empty()) {
            ImGui::Separator();
            ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "Error:");
            ImGui::TextWrapped("%s", compileError.c_str());
        }
        ImGui::End();
    }

    if (showFragmentEditor) {
        ImGui::SetNextWindowPos(ImVec2(370, 60), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(350, 350), ImGuiCond_FirstUseEver);
        ImGui::Begin("Fragment Shader", &showFragmentEditor, ImGuiWindowFlags_None);
        ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), "Fragment Shader");
        ImGui::Separator();
        
        static char fragmentBuf[8192] = "";
        strncpy(fragmentBuf, fragmentCode.c_str(), sizeof(fragmentBuf) - 1);
        fragmentBuf[sizeof(fragmentBuf) - 1] = '\0';
        ImGui::InputTextMultiline("##fragment", fragmentBuf, IM_ARRAYSIZE(fragmentBuf), ImVec2(-1, -1), ImGuiInputTextFlags_None);
        fragmentCode = fragmentBuf;

        if (ImGui::Button("Compile (F5)", ImVec2(-1, 0))) {
            compileShader();
            showHint = true;
            hintTimer = 0.0f;
        }
        ImGui::SameLine();
        if (ImGui::Button("Reset", ImVec2(-1, 0))) {
            fragmentCode = defaultFragmentShader;
            strncpy(fragmentBuf, defaultFragmentShader, sizeof(fragmentBuf) - 1);
            fragmentBuf[sizeof(fragmentBuf) - 1] = '\0';
            compileShader();
        }

        if (!compileError.empty()) {
            ImGui::Separator();
            ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "Error:");
            ImGui::TextWrapped("%s", compileError.c_str());
        }
        ImGui::End();
    }

    if (showComputeEditor) {
        ImGui::SetNextWindowPos(ImVec2(730, 60), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(350, 350), ImGuiCond_FirstUseEver);
        ImGui::Begin("Compute Shader", &showComputeEditor, ImGuiWindowFlags_None);
        ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), "Compute Shader");
        ImGui::Separator();

        bool wasUsingCompute = useComputeShader;
        ImGui::Checkbox("Use compute shader", &useComputeShader);
        if (useComputeShader && !wasUsingCompute)
        {
            if (!compileComputeShader(true))
            {
                showCompileErrorPopup = true;
            }

            showHint = true;
            hintTimer = 0.0f;
        }
        ImGui::Separator();

        static char computeBuf[16384] = "";
        strncpy(computeBuf, computeCode.c_str(), sizeof(computeBuf) - 1);
        computeBuf[sizeof(computeBuf) - 1] = '\0';
        ImGui::InputTextMultiline("##compute", computeBuf, IM_ARRAYSIZE(computeBuf), ImVec2(-1, -1), ImGuiInputTextFlags_None);
        computeCode = computeBuf;

        if (ImGui::Button("Compile Compute", ImVec2(-1, 0))) {
            compileComputeShader();
            showHint = true;
            hintTimer = 0.0f;
        }
        ImGui::SameLine();
        if (ImGui::Button("Reset", ImVec2(-1, 0))) {
            computeCode = defaultComputeShader;
            strncpy(computeBuf, defaultComputeShader, sizeof(computeBuf) - 1);
            computeBuf[sizeof(computeBuf) - 1] = '\0';
            compileComputeShader();
        }

        if (!computeCompileError.empty()) {
            ImGui::Separator();
            ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "Error:");
            ImGui::TextWrapped("%s", computeCompileError.c_str());
        } else if (useComputeShader && !computeValid) {
            ImGui::Separator();
            ImGui::TextColored(ImVec4(1.0f, 0.8f, 0.0f, 1.0f), "Compute shader is enabled but not compiled. Press Compile Compute.");
        }
        ImGui::End();
    }
}

void App::compileShader()
{
    shaderValid = false;
    computeValid = false;

    compileError.clear();
    computeCompileError.clear();
    compileErrorPopupMessage.clear();
    hintMessage.clear();

    // =========================
    // 1. Vertex / Fragment
    // =========================
    bool shaderOk = shader.compile(vertexCode, fragmentCode, compileError);

    if (!shaderOk)
    {
        compileErrorPopupMessage =
            "Shader compilation failed:\n" + compileError;
    }

    // =========================
    // 2. Compute (optional)
    // =========================
    bool computeOk = true;

    if (useComputeShader)
    {
        std::string computeSource = extractFirstShaderStage(computeCode);

        computeOk = computeShader.compileCompute(computeSource, computeCompileError);

        if (!computeOk)
        {
            if (!compileErrorPopupMessage.empty())
                compileErrorPopupMessage += "\n\n--- Compute Shader ---\n";
            else
                compileErrorPopupMessage += "--- Compute Shader ---\n";

            compileErrorPopupMessage +=
                "Compute shader compilation failed:\n" + computeCompileError;
        }
    }

    // =========================
    // 3. Update state
    // =========================
    shaderValid = shaderOk;
    computeValid = computeOk;

    bool overallOk = shaderOk && (!useComputeShader || computeOk);

    // =========================
    // 4. Result handling
    // =========================
    if (overallOk)
    {
        std::ostringstream msg;

        msg << "✓ Shader compilation successful\n\n";
        msg << "Pipeline status:\n";
        msg << " - Vertex/Fragment: OK\n";

        if (useComputeShader)
            msg << " - Compute Shader: OK\n";
        else
            msg << " - Compute Shader: Disabled\n";

        msg << "\nGPU program is now active and rendering with the updated shader state.\n";
        msg << "Time elapsed: " << time << " seconds\n";

        hintMessage = msg.str();

        std::cout << hintMessage << std::endl;
    }
    else
    {
        std::ostringstream msg;

        msg << "Shader compilation failed\n\n";
        msg << "One or more shader stages failed to compile.\n";
        msg << "The previous valid shader (if any) is still active.\n\n";

        msg << "----- Vertex / Fragment Stage -----\n";
        msg << compileError << "\n";

        if (useComputeShader)
        {
            msg << "----- Compute Shader Stage -----\n";
            msg << computeCompileError << "\n";
        }

        msg << "\nCommon causes:\n";
        msg << " - GLSL syntax error or missing semicolon\n";
        msg << " - Invalid uniform or attribute name\n";
        msg << " - Incorrect #version for driver support\n";
        msg << " - Texture/image binding mismatch\n";

        msg << "\nTip: isolate the error by disabling compute shader or reverting to default fragment shader.";

        compileErrorPopupMessage = msg.str();
        hintMessage = "Shader compilation failed.";

        showCompileErrorPopup = true;
        compileErrorPopupTimer = 0.0f;

        std::cerr << "Shader compilation failed:\n"
                << compileErrorPopupMessage << std::endl;
    }
}

std::string App::extractFirstShaderStage(const std::string& source)
{
    size_t first = source.find("#version");
    if (first == std::string::npos) {
        return source;
    }

    size_t second = source.find("#version", first + 8);
    if (second == std::string::npos) {
        return source;
    }

    return source.substr(first, second - first);
}

bool App::compileComputeShader(bool showPopup)
{
    if (!useComputeShader)
    {
        computeValid = false;
        computeCompileError.clear();
        return false;
    }
    computeCompileError.clear();
    if (!showPopup) {
        compileErrorPopupMessage.clear();
    }
    std::string computeSource = extractFirstShaderStage(computeCode);

    if (computeShader.compileCompute(computeSource, computeCompileError)) {
        computeValid = true;

        std::ostringstream msg;

        msg << "✓ Compute shader compiled successfully\n\n";
        msg << "Compute pipeline is now active.\n";
        msg << "Dispatch will run at next frame.\n";

        if (showPopup)
            hintMessage = msg.str();
        else
            hintMessage = "Compute shader compiled (silent mode)";

        std::cout << msg.str() << std::endl;
        return true;
    } else {
        computeValid = false;

        std::ostringstream msg;

        msg << "Compute shader compilation failed\n\n";
        msg << "The compute stage could not be executed on the GPU.\n\n";

        msg << "Error log:\n";
        msg << computeCompileError << "\n\n";

        msg << "Possible causes:\n";
        msg << " - Invalid image binding (layout/binding mismatch)\n";
        msg << " - Missing memory barrier usage assumptions\n";
        msg << " - Wrong work group size or dispatch bounds\n";
        msg << " - GLSL 430 requirement not met\n";

        if (showPopup) {
            compileErrorPopupMessage = msg.str();
            showCompileErrorPopup = true;
            compileErrorPopupTimer = 0.0f;
        }

        std::cerr << msg.str() << std::endl;
        return false;
    }
}

void App::createComputeTexture(int width, int height)
{
    if (computeTexture) {
        glDeleteTextures(1, &computeTexture);
        computeTexture = 0;
    }

    if (width <= 0 || height <= 0) {
        return;
    }

    glGenTextures(1, &computeTexture);
    glBindTexture(GL_TEXTURE_2D, computeTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, width, height, 0, GL_RGBA, GL_FLOAT, nullptr);
    glBindTexture(GL_TEXTURE_2D, 0);
}

void App::destroyComputeTexture()
{
    if (computeTexture) {
        glDeleteTextures(1, &computeTexture);
        computeTexture = 0;
    }
}

std::filesystem::path App::getExecutableDirectory()
{
#ifdef _WIN32
    char buffer[MAX_PATH] = {};
    if (GetModuleFileNameA(NULL, buffer, MAX_PATH) == 0) {
        return std::filesystem::current_path();
    }
    return std::filesystem::path(buffer).remove_filename();
#else
    return std::filesystem::current_path();
#endif
}

std::filesystem::path App::getShadersFolder() const
{
    namespace fs = std::filesystem;
    fs::path shaderDir = fs::current_path() / "shaders";
    fs::create_directories(shaderDir);
    return shaderDir;
}

std::string App::makeSafePresetName(const std::string& name) const
{
    std::string safe;
    for (char c : name) {
        if (std::isalnum(static_cast<unsigned char>(c)) || c == '_' || c == '-') {
            safe.push_back(c);
        } else if (std::isspace(static_cast<unsigned char>(c))) {
            safe.push_back('_');
        } else {
            safe.push_back('_');
        }
    }
    if (safe.empty()) {
        safe = "preset";
    }
    while (!safe.empty() && std::isspace(static_cast<unsigned char>(safe.back()))) {
        safe.pop_back();
    }
    return safe;
}

bool App::savePreset(const std::string& name, const std::string& vertex, const std::string& fragment, const std::string& compute, bool computeEnabled, std::string& errorOut) const
{
    if (name.empty()) {
        errorOut = "Preset name cannot be empty.";
        return false;
    }

    std::string safeName = makeSafePresetName(name);
    auto dir = getShadersFolder();
    auto vertPath = dir / (safeName + ".vert.glsl");
    auto fragPath = dir / (safeName + ".frag.glsl");
    auto compPath = dir / (safeName + ".comp.glsl");
    auto metaPath = dir / (safeName + ".meta");

    std::ofstream vertFile(vertPath);
    if (!vertFile) {
        errorOut = "Unable to write vertex shader file: " + vertPath.string();
        return false;
    }
    vertFile << vertex;
    vertFile.close();

    std::ofstream fragFile(fragPath);
    if (!fragFile) {
        errorOut = "Unable to write fragment shader file: " + fragPath.string();
        return false;
    }
    fragFile << fragment;
    fragFile.close();

    std::ofstream compFile(compPath);
    if (!compFile) {
        errorOut = "Unable to write compute shader file: " + compPath.string();
        return false;
    }
    compFile << compute;
    compFile.close();

    std::ofstream metaFile(metaPath);
    if (!metaFile) {
        errorOut = "Unable to write preset metadata file: " + metaPath.string();
        return false;
    }
    metaFile << "useCompute=" << (computeEnabled ? "1" : "0") << "\n";
    metaFile.close();

    return true;
}

bool App::deletePreset(const std::string& name, std::string& errorOut) const
{
    if (name.empty()) {
        errorOut = "No preset selected for deletion.";
        return false;
    }

    std::string safeName = makeSafePresetName(name);
    auto dir = getShadersFolder();
    bool removedSomething = false;
    auto vertPath = dir / (safeName + ".vert.glsl");
    auto fragPath = dir / (safeName + ".frag.glsl");
    auto compPath = dir / (safeName + ".comp.glsl");
    auto metaPath = dir / (safeName + ".meta");

    std::error_code ec;
    if (std::filesystem::exists(vertPath) && std::filesystem::remove(vertPath, ec)) {
        removedSomething = true;
    }
    if (std::filesystem::exists(fragPath) && std::filesystem::remove(fragPath, ec)) {
        removedSomething = true;
    }
    if (std::filesystem::exists(compPath) && std::filesystem::remove(compPath, ec)) {
        removedSomething = true;
    }
    if (std::filesystem::exists(metaPath) && std::filesystem::remove(metaPath, ec)) {
        removedSomething = true;
    }
    if (!removedSomething) {
        errorOut = "No matching preset files found to delete.";
        return false;
    }
    return true;
}

bool App::loadPreset(const std::string& name, ShaderPreset& preset, std::string& errorOut) const
{
    if (name.empty()) {
        errorOut = "No preset selected.";
        return false;
    }

    std::string safeName = makeSafePresetName(name);
    auto dir = getShadersFolder();
    auto vertPath = dir / (safeName + ".vert.glsl");
    auto fragPath = dir / (safeName + ".frag.glsl");
    auto compPath = dir / (safeName + ".comp.glsl");

    if (!std::filesystem::exists(fragPath)) {
        errorOut = "Preset fragment shader not found: " + fragPath.string();
        return false;
    }

    std::ifstream fragFile(fragPath);
    if (!fragFile) {
        errorOut = "Unable to read fragment shader file: " + fragPath.string();
        return false;
    }
    std::stringstream fragBuffer;
    fragBuffer << fragFile.rdbuf();
    preset.fragmentCode = fragBuffer.str();

    if (std::filesystem::exists(vertPath)) {
        std::ifstream vertFile(vertPath);
        if (vertFile) {
            std::stringstream vertBuffer;
            vertBuffer << vertFile.rdbuf();
            preset.vertexCode = vertBuffer.str();
        } else {
            preset.vertexCode = defaultVertexShader;
        }
    } else {
        preset.vertexCode = defaultVertexShader;
    }

    if (std::filesystem::exists(compPath)) {
        std::ifstream compFile(compPath);
        if (compFile) {
            std::stringstream compBuffer;
            compBuffer << compFile.rdbuf();
            preset.computeCode = compBuffer.str();
        } else {
            preset.computeCode = defaultComputeShader;
        }
    } else {
        preset.computeCode = defaultComputeShader;
    }

    auto metaPath = dir / (safeName + ".meta");
    if (std::filesystem::exists(metaPath)) {
        std::ifstream metaFile(metaPath);
        if (metaFile) {
            std::string line;
            while (std::getline(metaFile, line)) {
                if (line.rfind("useCompute=", 0) == 0) {
                    preset.useComputeShader = (line.substr(11) == "1");
                    break;
                }
            }
        }
    } else {
        preset.useComputeShader = false;
    }

    preset.name = name;
    return true;
}

std::vector<ShaderPreset> App::getPresets() const
{
    std::vector<ShaderPreset> presets;
    auto dir = getShadersFolder();
    if (!std::filesystem::exists(dir)) {
        return presets;
    }

    struct PresetEntry { bool hasVert = false; bool hasFrag = false; };
    std::map<std::string, PresetEntry> presetMap;

    for (const auto& entry : std::filesystem::directory_iterator(dir)) {
        if (!entry.is_regular_file()) {
            continue;
        }
        std::string fileName = entry.path().filename().string();
        if (fileName.size() >= 10 && fileName.substr(fileName.size() - 10) == ".frag.glsl") {
            std::string baseName = fileName.substr(0, fileName.size() - 10);
            presetMap[baseName].hasFrag = true;
        } else if (fileName.size() >= 10 && fileName.substr(fileName.size() - 10) == ".vert.glsl") {
            std::string baseName = fileName.substr(0, fileName.size() - 10);
            presetMap[baseName].hasVert = true;
        }
    }

    for (const auto& [name, entry] : presetMap) {
        if (entry.hasFrag) {
            ShaderPreset preset;
            preset.name = name;
            presets.push_back(preset);
        }
    }

    std::sort(presets.begin(), presets.end(), [](auto& a, auto& b) {
        return a.name < b.name;
    });

    return presets;
}

void App::renderSavedShadersWindow()
{
    if (!showSavedShaders) {
        return;
    }

    ImGui::SetNextWindowPos(ImVec2(730, 60), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowSize(ImVec2(300, 350), ImGuiCond_FirstUseEver);

    if (!ImGui::Begin("Saved Shaders", &showSavedShaders, ImGuiWindowFlags_None)) {
        ImGui::End();
        return;
    }

    ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), "Saved Shader Presets");
    ImGui::Separator();

    static char presetNameBuf[256] = "";
    strncpy(presetNameBuf, newPresetName.c_str(), sizeof(presetNameBuf) - 1);
    presetNameBuf[sizeof(presetNameBuf) - 1] = '\0';
    ImGui::InputText("Preset name", presetNameBuf, sizeof(presetNameBuf));
    newPresetName = presetNameBuf;

    if (ImGui::Button("New")) {
        selectedPreset.clear();
        newPresetName.clear();
        presetNameBuf[0] = '\0';
        vertexCode = defaultVertexShader;
        fragmentCode = defaultFragmentShader;
        computeCode = defaultComputeShader;
        useComputeShader = false;
        compileShader();
        compileComputeShader();
        hintMessage = "New shader created.";
    }
    ImGui::SameLine();
    if (ImGui::Button("Save As")) {
        std::string error;
        if (newPresetName.empty()) {
            hintMessage = "Enter a name before saving.";
        } else if (savePreset(newPresetName, vertexCode, fragmentCode, computeCode, useComputeShader, error)) {
            selectedPreset = makeSafePresetName(newPresetName);
            hintMessage = "Saved preset '" + selectedPreset + "'.";
        } else {
            hintMessage = error;
        }
    }

    if (ImGui::Button("Update")) {
        if (selectedPreset.empty()) {
            hintMessage = "Select a preset to update.";
        } else {
            std::string error;
            if (savePreset(selectedPreset, vertexCode, fragmentCode, computeCode, useComputeShader, error)) {
                hintMessage = "Updated preset '" + selectedPreset + "'.";
            } else {
                hintMessage = error;
            }
        }
    }
    ImGui::SameLine();
    if (ImGui::Button("Delete")) {
        if (selectedPreset.empty()) {
            hintMessage = "Select a preset to delete.";
        } else {
            std::string error;
            if (deletePreset(selectedPreset, error)) {
                hintMessage = "Deleted preset '" + selectedPreset + "'.";
                selectedPreset.clear();
            } else {
                hintMessage = error;
            }
        }
    }

    ImGui::Separator();
    auto presets = getPresets();
    ImGui::Text("Available presets (%d):", static_cast<int>(presets.size()));
    ImGui::BeginChild("PresetsList", ImVec2(-1, 180), true, ImGuiWindowFlags_None);
    if (presets.empty()) {
        ImGui::TextDisabled("No saved presets found.");
    }
    for (const auto& preset : presets) {
        bool isSelected = preset.name == selectedPreset;
        if (ImGui::Selectable(preset.name.c_str(), isSelected)) {
            std::string error;
            ShaderPreset loaded;
            if (loadPreset(preset.name, loaded, error)) {
                selectedPreset = preset.name;
                newPresetName = selectedPreset;
                vertexCode = loaded.vertexCode;
                fragmentCode = loaded.fragmentCode;
                computeCode = loaded.computeCode;
                useComputeShader = loaded.useComputeShader;
                compileShader();
                compileComputeShader();
                hintMessage = "Loaded preset '" + selectedPreset + "'.";
            } else {
                hintMessage = error;
            }
        }
    }
    ImGui::EndChild();

    if (!hintMessage.empty()) {
        ImGui::Separator();
        ImGui::TextWrapped("%s", hintMessage.c_str());
    }

    ImGui::End();
}

void App::renderScene()
{
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, windowWidth, windowHeight);

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glBindVertexArray(VAO);

    bool renderOk = shaderValid;

    if (useComputeShader)
    {
        renderOk = renderOk && computeValid;
    }

    if (renderOk)
    {
        // ============================
        // STEP 1: RUN COMPUTE (if enabled)
        // ============================
        if (useComputeShader)
        {
            computeShader.use();

            glBindImageTexture(0, computeTexture, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F);

            computeShader.setFloat("uTime", time);
            computeShader.setVec2("uResolution", (float)windowWidth, (float)windowHeight);

            glDispatchCompute(
                (GLuint)(windowWidth + 15) / 16,
                (GLuint)(windowHeight + 15) / 16,
                1
            );

            glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

            glFinish();

            GLenum err = glGetError();
            if (err != GL_NO_ERROR)
            {
                std::cerr << "GL ERROR after compute: " << err << std::endl;
            }
        }

        // ============================
        // STEP 2: DRAW
        // ============================

        if (useComputeShader)
        {
            // Show compute output
            displayShader.use();
            displayShader.setInt("uTexture", 0);

            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, computeTexture);
        }
        else
        {
            // Normal fragment shader
            shader.use();

            shader.setFloat("uTime", time);
            shader.setVec2("uResolution", (float)windowWidth, (float)windowHeight);
            shader.setVec2("uMouse", 0.0f, 0.0f);
        }

        glDrawArrays(GL_TRIANGLES, 0, 6);
    }
    else
    {
        // fallback (logo/error)

        displayShader.use();
        displayShader.setInt("uTexture", 0);

        glActiveTexture(GL_TEXTURE0);

        if (logoLoaded && logoTexture != 0)
            glBindTexture(GL_TEXTURE_2D, logoTexture);
        else
            glBindTexture(GL_TEXTURE_2D, errorTexture);

        glDrawArrays(GL_TRIANGLES, 0, 6);
    }

    glBindVertexArray(0);
}

void App::updateBuffers()
{
    float vertices[] = {
        // triangle 1
        -1.0f, -1.0f,  0.0f, 0.0f,
         1.0f, -1.0f,  1.0f, 0.0f,
         1.0f,  1.0f,  1.0f, 1.0f,
        // triangle 2
        -1.0f, -1.0f,  0.0f, 0.0f,
         1.0f,  1.0f,  1.0f, 1.0f,
        -1.0f,  1.0f,  0.0f, 1.0f,
    };

    glGenVertexArrays(1, &VAO);
    glBindVertexArray(VAO);

    glGenBuffers(1, &VBO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    glEnableVertexAttribArray(1);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
}
