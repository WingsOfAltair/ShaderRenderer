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
#define NOMINMAX
#include <windows.h>
#endif
#define STB_IMAGE_IMPLEMENTATION
#include <stb_image.h>

// Default vertex shader
const char* App::defaultVertexShader = R"(
#version 330 core

layout(location = 0) in vec2 aPos;

out vec2 uv;

void main()
{
    uv = aPos * 0.5 + 0.5; // convert -1..1 → 0..1
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
    int w = (windowWidth > 0) ? windowWidth : 1;
    int h = (windowHeight > 0) ? windowHeight : 1;

    if (w != windowWidth || h != windowHeight)
    {
        std::cerr << "Clamping FBO size from " << windowWidth << "x" << windowHeight
                  << " to " << w << "x" << h << std::endl;
    }

    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);

    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F,
        w, h, 0,
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
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if (tex) glDeleteTextures(1, &tex);
    if (fbo) glDeleteFramebuffers(1, &fbo);
    tex = 0;
    fbo = 0;
}

void App::handleResize()
{
    pendingResize = false;
    windowWidth = pendingWidth;
    windowHeight = pendingHeight;

    glViewport(0, 0, windowWidth, windowHeight);

    destroyFBO(backgroundFBO, backgroundTex);
    destroyFBO(shaderFBO, shaderTex);

    createFBO(backgroundFBO, backgroundTex);
    createFBO(shaderFBO, shaderTex);

    destroyComputeTexture();
    createComputeTexture(windowWidth, windowHeight);

    needsPingPongInit = false;
    forceRecompute = false;
}

App::App()
    : window(nullptr), windowWidth(1280), windowHeight(720), pendingWidth(1280), pendingHeight(720), pendingResize(false),
      shaderValid(false), computeValid(false), initComputeValid(false), useComputeShader(false), useParticleMode(false),
      useDualComputeShader(false), needInitDispatch(false), particleHasForce(true),
            computeTexture(0),
      pingPongTexA(0), pingPongTexB(0), pingPongReadTex(0), pingPongWriteTex(0),
      usePingPong(false), useR8UIPingPong(false), needsPingPongInit(true),
      gateVoltage(0.5f),
            particleVAO(0), particleBufferA(0), particleBufferB(0), particleReadBuffer(0), particleWriteBuffer(0), particleCount(0),
        time(0.0f), simulationTime(0.0f), lastSimulationTime(0.0f), internalSimTime(0.0f), lastFrameTime(0.0f), frameCount(0), fps(0.0f), simulationSpeed(1.0f), computeDt(0.016f),
        isPlaying(true), animationDuration(60.0f), loopAnimation(true), fastForwardRate(5.0f),
      isFastForwarding(false), isRewinding(false), showPlaybackBar(true), resetTimeOnCompile(false), useLogoAsChannel0(false),
      showHelp(false), showSavedShaders(true), showVertexEditor(true), showFragmentEditor(true), showComputeEditor(true),
      
      hintTimer(0.0f), showHint(false),
      showCompileErrorPopup(false), compileErrorPopupMessage(""), compileErrorPopupTimer(0.0f),
      VAO(0), VBO(0), selectedPreset(""), newPresetName(""), errorTexture(0)
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

    // -----------------------------
    // GLFW init
    // -----------------------------
    if (!glfwInit()) {
        std::cerr << "Failed to initialize GLFW\n";
        return false;
    }

    // IMPORTANT (VM COMPATIBILITY):
    // Request a lower OpenGL version first (3.3 is safer in VMware)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

#ifdef __APPLE__
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#endif

    // Optional but helps in VMs
    glfwWindowHint(GLFW_VISIBLE, GLFW_TRUE);
    glfwWindowHint(GLFW_DOUBLEBUFFER, GLFW_TRUE);

    // -----------------------------
    // Create window
    // -----------------------------
    window = glfwCreateWindow(width, height, title, nullptr, nullptr);
    if (!window) {
        std::cerr << "Failed to create GLFW window\n";
        glfwTerminate();
        return false;
    }

    glfwMakeContextCurrent(window);
    glfwSwapInterval(1); // vsync (stability in VM)

    glfwSetWindowUserPointer(window, this);

    // -----------------------------
    // Load OpenGL (GLAD)
    // -----------------------------
    if (!gladLoadGL(glfwGetProcAddress)) {
        std::cerr << "Failed to initialize OpenGL loader\n";
        glfwDestroyWindow(window);
        glfwTerminate();
        return false;
    }

    std::cout << "OpenGL: " << glGetString(GL_VERSION) << "\n";

    // -----------------------------
    // Resize callback (FIXED: no double user pointer reset)
    // -----------------------------
    glfwSetFramebufferSizeCallback(window,
        [](GLFWwindow* w, int ww, int hh)
        {
            auto* app = static_cast<App*>(glfwGetWindowUserPointer(w));
            if (!app) return;

            app->pendingWidth = std::max(ww, 1);
            app->pendingHeight = std::max(hh, 1);
            app->pendingResize = true;
        });

    // -----------------------------
    // OpenGL state
    // -----------------------------
    glViewport(0, 0, width, height);

    glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_PROGRAM_POINT_SIZE);

    // Debug output is NOT guaranteed in VM OpenGL 3.3
    int major = 0, minor = 0;
    glGetIntegerv(GL_MAJOR_VERSION, &major);
    glGetIntegerv(GL_MINOR_VERSION, &minor);

    if ((major > 4 || (major == 4 && minor >= 3)) && glDebugMessageCallback)
    {
        glEnable(GL_DEBUG_OUTPUT);
        glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);

        glDebugMessageCallback(
            [](GLenum, GLenum, GLuint, GLenum, GLsizei, const GLchar* msg, const void*)
            {
                std::cerr << "GL DEBUG: " << msg << "\n";
            },
            nullptr
        );
    }

    // -----------------------------
    // ImGui
    // -----------------------------
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();

    ImGuiIO& io = ImGui::GetIO();
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;

    // -----------------------------
    // FONT (must be loaded BEFORE backend init)
    // -----------------------------
        // -----------------------------
    // FONT (must be loaded BEFORE backend init)
    // -----------------------------
    namespace fs = std::filesystem;

    fs::path exeDir = getExecutableDirectory();
    fs::path sansPath  = exeDir / "fonts/NotoSans-Regular.ttf";
    fs::path emojiPath = exeDir / "fonts/fa-solid-900.ttf";

    ImFont* uiFont = nullptr;

    // =========================
    // 1. LOAD BASE FONT FIRST
    // =========================
    if (!fs::exists(sansPath))
    {
        std::cerr << "FATAL: Missing NotoSans font\n";
        return false;
    }

    static const ImWchar sansRanges[] = {
        0x0020, 0x00FF,
        0x2190, 0x21FF,
        0
    };

    uiFont = io.Fonts->AddFontFromFileTTF(
        sansPath.u8string().c_str(),
        18.0f,
        nullptr,
        sansRanges
    );

    if (!uiFont)
    {
        std::cerr << "FATAL: Failed to load NotoSans\n";
        return false;
    }
    // =========================
    // 2. MERGE EMOJI BEFORE BUILD
    // =========================
    if (fs::exists(emojiPath))
    {
        ImFontConfig cfg;
        cfg.MergeMode = true;
        cfg.PixelSnapH = true;
        cfg.OversampleH = 1;
        cfg.OversampleV = 1;
        cfg.GlyphMinAdvanceX = 0;

        static const ImWchar emojiRanges[] = {
             0xe000, 0xf8ff, 0
        };

        if (!io.Fonts->AddFontFromFileTTF(
                emojiPath.u8string().c_str(),
                18.0f,
                &cfg,
                emojiRanges))
        {
            std::cerr << "WARNING: Emoji font failed to load\n";
        }
    }
    else
    {
        std::cerr << "WARNING: Emoji font missing\n";
    }

    // =========================
    // 3. CRITICAL: BUILD ATLAS ONCE
    // =========================
    io.FontDefault = uiFont;

    // -----------------------------
    // Backend init (SAFE ORDER)
    // -----------------------------
    ImGui_ImplGlfw_InitForOpenGL(window, true);
    ImGui_ImplOpenGL3_Init("#version 330");

    // -----------------------------
    // Style
    // -----------------------------
    ImGui::StyleColorsDark();

    // -----------------------------
    // Shader setup
    // -----------------------------
    vertexCode   = defaultVertexShader;
    fragmentCode = defaultFragmentShader;
    computeCode  = defaultComputeShader;

    compileShader();
    displayShader.compile(
        defaultDisplayVertexShader,
        defaultDisplayFragmentShader,
        compileError
    );

    std::cout << "Display shader compile: " << compileError << std::endl;

    // -----------------------------
    // GPU resources
    // -----------------------------
    if (VAO) glDeleteVertexArrays(1, &VAO);
    if (VBO) glDeleteBuffers(1, &VBO);

    VAO = 0;
    VBO = 0;

    updateBuffers();
    createParticleBuffers(1024);

    loadLogoTexture();
    createErrorTexture();

    createFBO(backgroundFBO, backgroundTex);
    createFBO(shaderFBO, shaderTex);

    const char* version = (const char*)glGetString(GL_VERSION);
    std::cout << "GL Version String: " << version << "\n";

    bool hasCompute = strstr(version, "4.3") || strstr(version, "4.4") || strstr(version, "4.5") || strstr(version, "4.6");

    if (hasCompute)
    {
        createComputeTexture(windowWidth, windowHeight);
        compileComputeShader();
    }
    else
    {
        std::cout << "Compute shaders not supported, skipping...\n";
    }

    lastFrameTime = (float)glfwGetTime();
    computeDt = 0.016f;

    // Ping pong init
    createPingPongTextures(width, height);

    pingPongReadTex  = pingPongTexA;
    pingPongWriteTex = pingPongTexB;

    seedPingPongTexture(pingPongReadTex, width, height);
    seedPingPongTexture(pingPongWriteTex, width, height);

    needsPingPongInit = false;
    forceRecompute = false;

    return true;
}

void App::requestShutdown()
{
    if (shuttingDown)
        return;

    shuttingDown = true;

    if (window)
        glfwSetWindowShouldClose(window, GLFW_TRUE);
}

void App::run()
{
    while (!glfwWindowShouldClose(window))
    {
        glfwPollEvents();

        if (pendingResize)
            handleResize();

        if (shuttingDown)
            break;

        // -------------------------
        // Input
        // -------------------------
        if (glfwGetKey(window, GLFW_KEY_F5) == GLFW_PRESS)
        {
            compileShader(true);
            showHint = true;
            hintTimer = 0.0f;
        }

        // -------------------------
        // Update
        // -------------------------
        float currentTime = (float)glfwGetTime();
        float deltaTime = currentTime - lastFrameTime;
        lastFrameTime = currentTime;
        if (deltaTime <= 0.0f)
            deltaTime = 0.016f;
        if (deltaTime > 0.1f)
            deltaTime = 0.1f;

                time += deltaTime;

                // --- Advance simulation time according to playback state ---
                lastSimulationTime = simulationTime;

                if (isPlaying || isFastForwarding || isRewinding)
                {
                    float effectiveSpeed = simulationSpeed;
                    if (isFastForwarding) effectiveSpeed *= fastForwardRate;
                    if (isRewinding)      effectiveSpeed *= -fastForwardRate;

                    float advance  = deltaTime * effectiveSpeed;
                    simulationTime += advance;

                    if (loopAnimation)
                    {
                        if (simulationTime >= animationDuration)
                            simulationTime = fmodf(simulationTime, animationDuration);
                        else if (simulationTime < 0.0f)
                            simulationTime = animationDuration + fmodf(simulationTime, animationDuration);
                    }
                    else
                    {
                        if (simulationTime >= animationDuration)
                        {
                            simulationTime = animationDuration;
                            isPlaying      = false;
                        }
                        simulationTime = std::max(simulationTime, 0.0f);
                    }

                    // computeDt should reflect the intended step size for this frame.
                    // It drives the particle engine (N-Body).
                    computeDt = advance;
                }
                else
                {
                    computeDt = 0.0f;
                }

        // -------------------------
        // UI
        // -------------------------
        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplGlfw_NewFrame();
        ImGui::NewFrame();

        renderUI();
        renderScene();

        ImGui::Render();
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());

        glfwSwapBuffers(window);
    }
    shutdown();
}

void App::shutdown()
{
    if (shuttingDown)
        return;

    shuttingDown = true;

    if (window)
    {
        glfwMakeContextCurrent(window);

        glFinish(); // ensure GPU is done
    }

    if (VAO)
    {
        glDeleteVertexArrays(1, &VAO);
        VAO = 0;
    }

    if (VBO)
    {
        glDeleteBuffers(1, &VBO);
        VBO = 0;
    }

    destroyComputeTexture();
    destroyParticleBuffers();

    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();

    if (window)
    {
        glfwDestroyWindow(window);
        window = nullptr;
    }

    glfwTerminate();
}

void App::renderUI()
{
    hintTimer += 0.016f;
    if (hintTimer > 10.0f)
        showHint = false;

    // =========================
    // MAIN MENU
    // =========================
    if (ImGui::BeginMainMenuBar())
    {
        if (ImGui::BeginMenu("Shader"))
        {
            if (ImGui::MenuItem("Reload (F5)"))
            {
                compileShader(true);
                showHint = true;
                hintTimer = 0.0f;
            }

            if (ImGui::MenuItem("Load test shader"))
            {
                fragmentCode = testFragmentShader;
                compileShader();
                showHint = true;
                hintTimer = 0.0f;
            }

            if (ImGui::MenuItem("Reset to default"))
            {
                vertexCode = defaultVertexShader;
                fragmentCode = defaultFragmentShader;
                computeCode = defaultComputeShader;
                useComputeShader = false;

                compileShader(true);
                compileComputeShader();

                showHint = true;
                hintTimer = 0.0f;
            }

            ImGui::Separator();

            if (ImGui::MenuItem("Exit", "Alt+F4"))
                requestShutdown();

            ImGui::EndMenu();
        }

        if (ImGui::BeginMenu("View"))
        {
            ImGui::MenuItem("Help", nullptr, &showHelp);
            ImGui::MenuItem("Vertex Shader", nullptr, &showVertexEditor);
            ImGui::MenuItem("Fragment Shader", nullptr, &showFragmentEditor);
            ImGui::MenuItem("Compute Shader", nullptr, &showComputeEditor);
            ImGui::MenuItem("Saved Shaders", nullptr, &showSavedShaders);
            ImGui::Separator();
            ImGui::MenuItem("Playback Bar", nullptr, &showPlaybackBar);
            ImGui::EndMenu();
        }

        ImGui::EndMainMenuBar();
    }

    // =========================
    // HINT TIMER
    // =========================
    if (showHint)
    {
        ImGui::SetNextWindowPos(ImVec2(10, 60), ImGuiCond_Always);
        ImGui::Begin("Hint",
                     nullptr,
                     ImGuiWindowFlags_NoDecoration |
                     ImGuiWindowFlags_NoInputs |
                     ImGuiWindowFlags_NoSavedSettings);

        ImGui::TextColored(ImVec4(0, 1, 0, 1), "%s", hintMessage.c_str());
        ImGui::End();
    }

    // =========================
    // ERROR POPUP TIMER
    // =========================
    if (showCompileErrorPopup)
    {
        compileErrorPopupTimer += 0.016f;
        if (compileErrorPopupTimer >= 10.0f)
        {
            showCompileErrorPopup = false;
            compileErrorPopupTimer = 0.0f;
        }
    }

    // =========================
    // ERROR POPUP
    // =========================
    if (showCompileErrorPopup)
    {
        ImGui::SetNextWindowPos(
            ImVec2(ImGui::GetIO().DisplaySize.x * 0.5f,
                   ImGui::GetIO().DisplaySize.y * 0.5f),
            ImGuiCond_FirstUseEver);

        ImGui::SetNextWindowSize(ImVec2(500, 300), ImGuiCond_FirstUseEver);

        if (ImGui::Begin("Shader Compilation Error", &showCompileErrorPopup))
        {
            ImGui::TextColored(ImVec4(1, 0.3f, 0.3f, 1),
                               "Compilation failed (auto close in %.0f s)",
                               10.0f - compileErrorPopupTimer);

            ImGui::Separator();
            ImGui::TextWrapped("%s", compileErrorPopupMessage.c_str());

            ImGui::Separator();

            if (ImGui::Button("Copy"))
                ImGui::SetClipboardText(compileErrorPopupMessage.c_str());

            if (ImGui::Button("Close"))
            {
                showCompileErrorPopup = false;
                compileErrorPopupTimer = 0.0f;
            }
        }
        ImGui::End();
    }

    // =========================
    // HELP
    // =========================
    if (showHelp)
    {
        ImGui::SetNextWindowPos(ImVec2(10, 60), ImGuiCond_Always);
        ImGui::Begin("Help", &showHelp);

        ImGui::Text("F5 - Reload shader");
        ImGui::Text("Edit shaders live");
        ImGui::Text("Compute shader optional");

        ImGui::End();
    }

        // =========================
    // SAVED SHADERS
    // =========================
    renderSavedShadersWindow();

    // =========================
    // PLAYBACK BAR
    // =========================
    renderPlaybackBar();

    // =========================
    // FIXED SHADER EDITOR WINDOWS (IMPORTANT PATCH)
    // =========================

    // Vertex Shader
    if (showVertexEditor)
    {
        ImGui::SetNextWindowSize(ImVec2(450, 450), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowPos(ImVec2(10, 60), ImGuiCond_FirstUseEver);

        ImGui::Begin("Vertex Shader", &showVertexEditor);

        static char vertexBuf[8192];
        strcpy(vertexBuf, vertexCode.c_str());

        if (ImGui::InputTextMultiline("##v", vertexBuf, sizeof(vertexBuf), ImVec2(-1, -1)))
            vertexCode = vertexBuf;

        if (ImGui::Button("Compile"))
            compileShader(resetTimeOnCompile);

        if (ImGui::Button("Reset"))
        {
            vertexCode = defaultVertexShader;
            compileShader(resetTimeOnCompile);
        }

        ImGui::End();
    }

    // Fragment Shader
    if (showFragmentEditor)
    {
        ImGui::SetNextWindowSize(ImVec2(450, 450), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowPos(ImVec2(370, 60), ImGuiCond_FirstUseEver);

        ImGui::Begin("Fragment Shader", &showFragmentEditor);

        static char fragmentBuf[8192];
        strcpy(fragmentBuf, fragmentCode.c_str());

        if (ImGui::InputTextMultiline("##f", fragmentBuf, sizeof(fragmentBuf), ImVec2(-1, -1)))
            fragmentCode = fragmentBuf;

        if (ImGui::Button("Compile"))
            compileShader(resetTimeOnCompile);

        if (ImGui::Button("Reset"))
        {
            fragmentCode = defaultFragmentShader;
            compileShader(resetTimeOnCompile);
        }

        ImGui::End();
    }

    // Compute Shader
    if (showComputeEditor)
    {
        ImGui::SetNextWindowSize(ImVec2(500, 500), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowPos(ImVec2(730, 60), ImGuiCond_FirstUseEver);

        ImGui::Begin("Compute Shader", &showComputeEditor);

        bool prevUse = useComputeShader;
        ImGui::Checkbox("Enable compute", &useComputeShader);

        bool prevParticleMode = useParticleMode;
        ImGui::Checkbox("Particle rendering", &useParticleMode);
        ImGui::TextWrapped("Particle mode uses the current vertex/fragment shader to draw points from the SSBO.\n"
                         "Vertex shader inputs should match the particle buffer layout at locations 0, 1, 2, and 3.");
        ImGui::TextWrapped("Optional compute shader sections: use 'init #version' for one-time setup and 'update #version' for per-frame updates.");

        if (useComputeShader != prevUse)
        {
            if (useComputeShader)
            {
                createComputeTexture(windowWidth, windowHeight);
                compileComputeShader(true);
            }
            else
            {
                computeValid = false;
                destroyComputeTexture();
            }

            compileShader(useParticleMode);
        }
        else if (useParticleMode != prevParticleMode)
        {
            compileShader(true);
        }

        static char computeBuf[16384];
        strcpy(computeBuf, computeCode.c_str());

        if (ImGui::InputTextMultiline("##c", computeBuf, sizeof(computeBuf), ImVec2(-1, -1)))
            computeCode = computeBuf;

                if (ImGui::Button("Compile Compute"))
            compileComputeShader();

        if (computeCode.find("gateVoltage") != std::string::npos ||
            fragmentCode.find("gateVoltage") != std::string::npos ||
            vertexCode.find("gateVoltage") != std::string::npos)
        {
            ImGui::SliderFloat("Gate Voltage", &gateVoltage, 0.0f, 5.0f);
        }

        ImGui::SameLine();
        if (ImGui::Button("Reset"))
        {
            computeCode = defaultComputeShader;
            compileComputeShader();
        }

        ImGui::SliderFloat("Simulation speed", &simulationSpeed, 0.1f, 10000.0f, "%.2fx", ImGuiSliderFlags_Logarithmic);
        ImGui::SetItemTooltip("Simulation speed multiplier (shared with Playback Bar)");
        ImGui::Text("Compute dt = %.6f", computeDt);

        ImGui::End();
    }
}

void App::compileShader(bool resetParticles)
{
    shaderValid = false;
    computeValid = false;

    compileError.clear();
    computeCompileError.clear();
    compileErrorPopupMessage.clear();
    hintMessage.clear();

    showCompileErrorPopup = false;
    compileErrorPopupTimer = 0.0f;

    // =========================
    // 1. Vertex / Fragment
    // =========================
    std::string vertexSource = vertexCode;
    std::string fragmentSource = fragmentCode;
    bool extractedStages = false;

    if (useComputeShader)
    {
        CombinedShaderSources combined = splitCombinedShaderSources(computeCode);
        if (!combined.vertexSource.empty() && !combined.fragmentSource.empty())
        {
            vertexSource = combined.vertexSource;
            fragmentSource = combined.fragmentSource;
            vertexCode = combined.vertexSource;
            fragmentCode = combined.fragmentSource;
            extractedStages = true;
        }
    }

    bool shaderOk = shader.compile(vertexSource, fragmentSource, compileError);

    std::ostringstream popup;

    if (!shaderOk)
    {
        popup << "Shader compilation failed:\n";
        popup << compileError << "\n";
    }

    // =========================
    // 2. Compute (optional)
    // =========================
    bool computeOk = true;

    if (useComputeShader)
    {
        // Compile the full compute pipeline so init/update blocks are handled correctly.
        computeOk = compileComputeShader(false);

        if (!computeOk)
        {
            popup << "\n--- Compute Shader ---\n";
            popup << "Compute shader compilation failed:\n";
            if (!computeCompileError.empty())
                popup << computeCompileError << "\n";
            if (!initComputeCompileError.empty())
                popup << initComputeCompileError << "\n";
        }
    }

    // =========================
    // 3. Update state
    // =========================
    shaderValid = shaderOk;
    // compileComputeShader already updates computeValid/initComputeValid
    if (useComputeShader)
        computeValid = computeOk;

    bool overallOk = shaderOk && (!useComputeShader || computeOk);

    // =========================
    // 4. Result handling
    // =========================
    if (overallOk)
    {
        std::ostringstream msg;

        msg << "✓ Vertex/Fragment shader compiled successfully\n\n";
        msg << "Pipeline status:\n";
        msg << " - Vertex Shader: OK\n";
        msg << " - Fragment Shader: OK\n";

        if (useComputeShader)
            msg << " - Compute Shader: OK\n";
        else
            msg << " - Compute Shader: Disabled\n";

        msg << "\nGPU program is now active.\n";
        msg << "Rendering updated shader pipeline in real-time.\n\n";

        msg << "Time elapsed: " << time << " seconds\n";

        hintMessage = msg.str();

        std::cout << hintMessage << std::endl;

        if (resetParticles)
        {
            if (useParticleMode)
                resetParticleState();
            time = 0.0f;
            simulationTime = 0.0f;
        }

        showHint = true;
        hintTimer = 0.0f;

        return;
    }

    // =========================
    // 5. Failure handling
    // =========================
    std::ostringstream msg;

    msg << "Shader compilation failed\n\n";
    msg << "One or more shader stages failed to compile.\n";
    msg << "The previous valid shader (if any) is still active.\n\n";

    if (!compileError.empty())
    {
        msg << "----- Vertex / Fragment Stage -----\n";
        msg << compileError << "\n";
    }

    if (useComputeShader && !computeCompileError.empty())
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

static std::string toLowerCopy(const std::string& s)
{
    std::string lower = s;
    std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c) { return std::tolower(c); });
    return lower;
}

static std::string trimWhitespace(const std::string& s)
{
    size_t start = 0;
    while (start < s.size() && std::isspace(static_cast<unsigned char>(s[start])))
        ++start;
    size_t end = s.size();
    while (end > start && std::isspace(static_cast<unsigned char>(s[end - 1])))
        --end;
    return s.substr(start, end - start);
}

CombinedShaderSources App::splitCombinedShaderSources(const std::string& source) const
{
    CombinedShaderSources result;
    std::string lowerSource = toLowerCopy(source);

    struct BlockInfo {
        size_t versionPos;
        size_t endPos;
        size_t labelPos;
        bool isInitLabel;
        bool isUpdateLabel;
        std::string text;
    };

    std::vector<BlockInfo> blocks;
    size_t pos = 0;

    while (true) {
        size_t versionPos = lowerSource.find("#version", pos);
        if (versionPos == std::string::npos)
            break;

        size_t lineStart = lowerSource.rfind('\n', versionPos);
        if (lineStart == std::string::npos)
            lineStart = 0;
        else
            lineStart += 1;

        std::string line = trimWhitespace(source.substr(lineStart, versionPos - lineStart));
        bool isInitLabel = false;
        bool isUpdateLabel = false;
        if (!line.empty()) {
            std::istringstream iss(line);
            std::string token;
            if (iss >> token) {
                std::string lowerToken = toLowerCopy(token);
                if (lowerToken == "init")
                    isInitLabel = true;
                else if (lowerToken == "update")
                    isUpdateLabel = true;
            }
        }

        size_t nextVersion = lowerSource.find("#version", versionPos + 8);
        size_t endPos = (nextVersion == std::string::npos) ? source.size() : nextVersion;
        std::string blockText = source.substr(versionPos, endPos - versionPos);

        blocks.push_back({versionPos, endPos, lineStart, isInitLabel, isUpdateLabel, blockText});
        if (nextVersion == std::string::npos)
            break;
        pos = nextVersion;
    }

    auto classify = [&](const std::string& text) {
        std::string lowerText = toLowerCopy(text);
        if (lowerText.find("local_size_") != std::string::npos || lowerText.find("gl_globalinvocationid") != std::string::npos)
            return 0;
        if (lowerText.find("gl_position") != std::string::npos || lowerText.find("layout(location = 0) in") != std::string::npos || lowerText.find("gl_pervertex") != std::string::npos)
            return 1;
        if (lowerText.find("fragcolor") != std::string::npos || lowerText.find("gl_fragcolor") != std::string::npos || lowerText.find("out vec4") != std::string::npos || lowerText.find("texture(") != std::string::npos)
            return 2;
        return 3;
    };

    std::vector<BlockInfo*> computeBlocks;
    BlockInfo* initBlock = nullptr;
    BlockInfo* updateBlock = nullptr;
    BlockInfo* vertexBlock = nullptr;
    BlockInfo* fragmentBlock = nullptr;

    for (auto& block : blocks) {
        int type = classify(block.text);
        if (type == 0) {
            computeBlocks.push_back(&block);
            if (block.isInitLabel)
                initBlock = &block;
            if (block.isUpdateLabel)
                updateBlock = &block;
        } else if (type == 1 && !vertexBlock) {
            vertexBlock = &block;
        } else if (type == 2 && !fragmentBlock) {
            fragmentBlock = &block;
        }
    }

    if (initBlock && updateBlock && initBlock->versionPos < updateBlock->versionPos) {
        result.computeSources.initSource = source.substr(initBlock->versionPos, updateBlock->labelPos - initBlock->versionPos);
        result.computeSources.updateSource = source.substr(updateBlock->versionPos, updateBlock->endPos - updateBlock->versionPos);
    } else if (computeBlocks.size() >= 2) {
        result.computeSources.initSource = computeBlocks[0]->text;
        result.computeSources.updateSource = computeBlocks[1]->text;
    } else if (computeBlocks.size() == 1) {
        result.computeSources.updateSource = computeBlocks[0]->text;
    }

    if (vertexBlock)
        result.vertexSource = vertexBlock->text;
    if (fragmentBlock)
        result.fragmentSource = fragmentBlock->text;

    return result;
}

ComputeShaderSources App::splitComputeShaderSources(const std::string& source) const
{
    return splitCombinedShaderSources(source).computeSources;
}

static int parseLocalSize(const std::string& source, const std::string& key, int defaultValue)
{
    std::string lowerSource = toLowerCopy(source);
    std::string token = "local_size_" + key;
    size_t pos = lowerSource.find(token);
    if (pos == std::string::npos)
        return defaultValue;

    pos = lowerSource.find('=', pos);
    if (pos == std::string::npos)
        return defaultValue;

    ++pos;
    while (pos < lowerSource.size() && std::isspace(static_cast<unsigned char>(lowerSource[pos])))
        ++pos;

    int value = 0;
    while (pos < lowerSource.size() && std::isdigit(static_cast<unsigned char>(lowerSource[pos]))) {
        value = value * 10 + (lowerSource[pos] - '0');
        ++pos;
    }

    return value > 0 ? value : defaultValue;
}

int App::getComputeShaderLocalInvocationCount(const std::string& source) const
{
    int x = parseLocalSize(source, "x", 128);
    int y = parseLocalSize(source, "y", 1);
    int z = parseLocalSize(source, "z", 1);
    return std::max<int>(1, x) * std::max<int>(1, y) * std::max<int>(1, z);
}

bool App::computeSourceUsesWriteBinding1(const std::string& source) const
{
    std::string lowerSource = toLowerCopy(source);
    return lowerSource.find("binding = 1") != std::string::npos ||
           lowerSource.find("binding=1") != std::string::npos;
}

bool App::computeSourceUsesForce(const std::string& source) const
{
    std::string lowerSource = toLowerCopy(source);
    return lowerSource.find("vec4 force") != std::string::npos ||
           lowerSource.find("particles_out[gidx].force") != std::string::npos ||
           lowerSource.find("particles_in[gidx].force") != std::string::npos;
}

bool App::computeSourceUsesR8UI(const std::string& source) const
{
    std::string lowerSource = toLowerCopy(source);
    return lowerSource.find("r8ui") != std::string::npos;
}

bool App::compileComputeShader(bool showPopup)
{
    if (!useComputeShader)
    {
        computeValid = false;
        initComputeValid = false;
        computeCompileError.clear();
        initComputeCompileError.clear();
        return false;
    }

    computeCompileError.clear();
    initComputeCompileError.clear();
    if (!showPopup) {
        compileErrorPopupMessage.clear();
    }

    CombinedShaderSources combined = splitCombinedShaderSources(computeCode);
    ComputeShaderSources sources = combined.computeSources;

    bool newParticleHasForce = computeSourceUsesForce(sources.initSource + sources.updateSource);
    if (newParticleHasForce != particleHasForce)
    {
        particleHasForce = newParticleHasForce;
        if (particleCount > 0)
        {
            createParticleBuffers(particleCount);
            if (useParticleMode)
                resetParticleState();
        }
    }

        bool computeNeedsPingPong = computeSourceUsesWriteBinding1(sources.initSource + sources.updateSource) || !sources.initSource.empty();
    if (!computeNeedsPingPong && particleCount > 0)
    {
        particleWriteBuffer = particleReadBuffer;
    }

        // Detected compute types
        bool isParticleSimulation = useParticleMode;
        bool needsR8UI = computeSourceUsesR8UI(sources.initSource + sources.updateSource);
        bool usesBinding1 = computeSourceUsesWriteBinding1(sources.initSource + sources.updateSource);
        bool hasInitBlock = !sources.initSource.empty();
    
        // The MOSFET and texture-based simulations need the IterativeEngine (sub-stepping).
        // We detect this if we have binding 1 but we are NOT in particle mode.
        useIterativeEngine = (usesBinding1 || hasInitBlock) && !isParticleSimulation;

        // usePingPong is a flag used in renderScene to decide which dispatch logic to use.
        // It should be true for both MOSFET (textures) and N-Body (SSBOs) if they have binding 1.
        if (usesBinding1 != usePingPong || needsR8UI != useR8UIPingPong)
        {
            usePingPong = usesBinding1;
            useR8UIPingPong = needsR8UI;

            if (useIterativeEngine) internalSimTime = 0.0f;
        
            // Only manage textures if we ARE NOT in particle mode.
            // N-Body manages its own particleReadBuffer/particleWriteBuffer.
            if (!isParticleSimulation)
            {
                if (computeTexture) { glDeleteTextures(1, &computeTexture); computeTexture = 0; }
                destroyPingPongTextures();

                if (usePingPong)
                    createPingPongTextures(windowWidth, windowHeight);
                else
                    createComputeTexture(windowWidth, windowHeight);
            }
        }
        if (usePingPong && !isParticleSimulation)
            needsPingPongInit = true;
        else if (isParticleSimulation)
            needsPingPongInit = false;

    if (!combined.vertexSource.empty() && !combined.fragmentSource.empty())
    {
        vertexCode = combined.vertexSource;
        fragmentCode = combined.fragmentSource;

        std::string vertexFragError;
        bool shaderOk = shader.compile(vertexCode, fragmentCode, vertexFragError);
        if (!shaderOk)
        {
            compileError = vertexFragError;
            if (showPopup)
            {
                compileErrorPopupMessage = "Vertex/Fragment compilation failed while importing from compute source.\n" + compileError;
                showCompileErrorPopup = true;
                compileErrorPopupTimer = 0.0f;
            }
            return false;
        }
        shaderValid = true;
    }

    bool initOk = true;
    if (!sources.initSource.empty())
    {
        initOk = initComputeShader.compileCompute(sources.initSource, initComputeCompileError);
    }

    bool updateOk = computeShader.compileCompute(sources.updateSource, computeCompileError);

    useDualComputeShader = !sources.initSource.empty() && initOk;
    needInitDispatch = useDualComputeShader;
    initComputeValid = initOk;
    computeValid = updateOk && (sources.initSource.empty() || initOk);

    if (computeValid)
    {
        std::ostringstream msg;

        msg << "✓ Compute shader compiled successfully\n\n";
        msg << "Compute pipeline is now active.\n";
        msg << "Dispatch will run at next frame.\n";
        if (useDualComputeShader)
            msg << "Init/update compute pipeline enabled.\n";

        if (showPopup)
            hintMessage = msg.str();
        else
            hintMessage = "Compute shader compiled (silent mode)";

        std::cout << msg.str() << std::endl;
        return true;
    }

    std::ostringstream msg;
    msg << "Compute shader compilation failed\n\n";
    msg << "The compute stage could not be executed on the GPU.\n\n";

    if (!computeCompileError.empty()) {
        msg << "----- Update Compute Stage -----\n";
        msg << computeCompileError << "\n\n";
    }
    if (!initComputeCompileError.empty()) {
        msg << "----- Init Compute Stage -----\n";
        msg << initComputeCompileError << "\n\n";
    }

    msg << "Possible causes:\n";
    msg << " - Invalid buffer binding (layout/binding mismatch)\n";
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

void App::createComputeTexture(int width, int height)
{
    if (computeTexture) {
        glDeleteTextures(1, &computeTexture);
        computeTexture = 0;
    }

    int w = (width > 0) ? width : 1;
    int h = (height > 0) ? height : 1;
    if (w != width || h != height)
    {
        std::cerr << "Clamping compute texture size from " << width << "x" << height
                  << " to " << w << "x" << h << std::endl;
    }

    // r8ui ping-pong path — two textures managed separately
    if (usePingPong)
    {
        createPingPongTextures(w, h);

        pingPongReadTex = pingPongTexA;
        pingPongWriteTex = pingPongTexB;

        if (useR8UIPingPong)
        {
            seedPingPongTexture(pingPongReadTex, w, h);
            seedPingPongTexture(pingPongWriteTex, w, h);
        }

        forceRecompute = true;
        needsPingPongInit = false;

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
    glBindImageTexture(0, 0, 0, GL_FALSE, 0, GL_READ_ONLY,  GL_R8UI);
    glBindImageTexture(1, 0, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_R8UI);
    glBindTexture(GL_TEXTURE_2D, 0);

    if (computeTexture) {
        glDeleteTextures(1, &computeTexture);
        computeTexture = 0;
    }
    destroyPingPongTextures();
}

void App::destroyPingPongTextures()
{
    if (pingPongTexA) { glDeleteTextures(1, &pingPongTexA); pingPongTexA = 0; }
    if (pingPongTexB) { glDeleteTextures(1, &pingPongTexB); pingPongTexB = 0; }
    pingPongReadTex = 0;
    pingPongWriteTex = 0;
}

void App::createPingPongTextures(int width, int height)
{
    destroyPingPongTextures();
    if (width <= 0 || height <= 0) return;

    auto makeR8UI = [](int w, int h) -> GLuint {
        GLuint tex;
        glGenTextures(1, &tex);
        glBindTexture(GL_TEXTURE_2D, tex);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_R8UI, w, h, 0, GL_RED_INTEGER, GL_UNSIGNED_BYTE, nullptr);
        glBindTexture(GL_TEXTURE_2D, 0);
        return tex;
    };

    auto makeRGBA32F = [](int w, int h) -> GLuint {
        GLuint tex;
        glGenTextures(1, &tex);
        glBindTexture(GL_TEXTURE_2D, tex);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, w, h, 0, GL_RGBA, GL_FLOAT, nullptr);
        glBindTexture(GL_TEXTURE_2D, 0);
        return tex;
    };

    if (useR8UIPingPong)
    {
        pingPongTexA = makeR8UI(width, height);
        pingPongTexB = makeR8UI(width, height);
    }
    else
    {
        pingPongTexA = makeRGBA32F(width, height);
        pingPongTexB = makeRGBA32F(width, height);
    }

    pingPongReadTex  = pingPongTexA;
    pingPongWriteTex = pingPongTexB;
}

void App::seedPingPongTexture(GLuint tex, int width, int height)
{
    if (!tex || width <= 0 || height <= 0)
        return;

    std::vector<unsigned char> data(width * height);
    for (auto& cell : data)
        cell = (rand() % 5 == 0) ? 1u : 0u;  // ~20% alive

    GLint prevAlignment = 0;
    glGetIntegerv(GL_UNPACK_ALIGNMENT, &prevAlignment);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    glBindTexture(GL_TEXTURE_2D, tex);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height,
                    GL_RED_INTEGER, GL_UNSIGNED_BYTE, data.data());
    glBindTexture(GL_TEXTURE_2D, 0);

    glPixelStorei(GL_UNPACK_ALIGNMENT, prevAlignment);
}

void App::destroyParticleBuffers()
{
    if (particleBufferA) {
        glDeleteBuffers(1, &particleBufferA);
        particleBufferA = 0;
    }
    if (particleBufferB) {
        glDeleteBuffers(1, &particleBufferB);
        particleBufferB = 0;
    }
    if (particleVAO) {
        glDeleteVertexArrays(1, &particleVAO);
        particleVAO = 0;
    }
    particleReadBuffer = 0;
    particleWriteBuffer = 0;
    particleCount = 0;
}

void App::createParticleBuffers(int count)
{
    destroyParticleBuffers();
    if (count <= 0) {
        return;
    }

    if (particleHasForce)
    {
        struct Particle {
            float position[4];
            float velocity[4];
            float force[4];
            float mass;
            float padding[3];
        };

        std::vector<Particle> particles(count);
        for (int i = 0; i < count; ++i) {
            float t = (float)i / (float)count;
            float angle = t * 6.2831853f * 4.0f;
            float radius = 0.25f + 0.5f * t;
            particles[i].position[0] = radius * cos(angle);
            particles[i].position[1] = radius * sin(angle);
            particles[i].position[2] = 0.0f;
            particles[i].position[3] = 1.0f;
            particles[i].velocity[0] = 0.0f;
            particles[i].velocity[1] = 0.0f;
            particles[i].velocity[2] = 0.0f;
            particles[i].velocity[3] = 0.0f;
            particles[i].force[0] = 0.0f;
            particles[i].force[1] = 0.0f;
            particles[i].force[2] = 0.0f;
            particles[i].force[3] = 0.0f;
            particles[i].mass = 1.0f;
            particles[i].padding[0] = particles[i].padding[1] = particles[i].padding[2] = 0.0f;
        }

        particleCount = count;
        glGenVertexArrays(1, &particleVAO);
        glGenBuffers(1, &particleBufferA);
        glGenBuffers(1, &particleBufferB);

        glBindVertexArray(particleVAO);

        glBindBuffer(GL_ARRAY_BUFFER, particleBufferA);
        glBufferData(GL_ARRAY_BUFFER, particleCount * sizeof(Particle), particles.data(), GL_DYNAMIC_DRAW);

        glBindBuffer(GL_ARRAY_BUFFER, particleBufferB);
        glBufferData(GL_ARRAY_BUFFER, particleCount * sizeof(Particle), particles.data(), GL_DYNAMIC_DRAW);

        particleReadBuffer = particleBufferA;
        particleWriteBuffer = particleBufferB;

        glBindBuffer(GL_ARRAY_BUFFER, particleReadBuffer);
        glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, sizeof(Particle), (void*)0);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, sizeof(Particle), (void*)(sizeof(float) * 4));
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, sizeof(Particle), (void*)(sizeof(float) * 8));
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(3, 1, GL_FLOAT, GL_FALSE, sizeof(Particle), (void*)(sizeof(float) * 12));
        glEnableVertexAttribArray(3);
    }
    else
    {
        struct Particle {
            float position[4];
            float velocity[4];
            float mass;
            float padding[3];
        };

        std::vector<Particle> particles(count);
        for (int i = 0; i < count; ++i) {
            float t = (float)i / (float)count;
            float angle = t * 6.2831853f * 4.0f;
            float radius = 0.25f + 0.5f * t;
            particles[i].position[0] = radius * cos(angle);
            particles[i].position[1] = radius * sin(angle);
            particles[i].position[2] = 0.0f;
            particles[i].position[3] = 1.0f;
            particles[i].velocity[0] = 0.0f;
            particles[i].velocity[1] = 0.0f;
            particles[i].velocity[2] = 0.0f;
            particles[i].velocity[3] = 0.0f;
            particles[i].mass = 1.0f;
            particles[i].padding[0] = particles[i].padding[1] = particles[i].padding[2] = 0.0f;
        }

        particleCount = count;
        glGenVertexArrays(1, &particleVAO);
        glGenBuffers(1, &particleBufferA);
        glGenBuffers(1, &particleBufferB);

        glBindVertexArray(particleVAO);

        glBindBuffer(GL_ARRAY_BUFFER, particleBufferA);
        glBufferData(GL_ARRAY_BUFFER, particleCount * sizeof(Particle), particles.data(), GL_DYNAMIC_DRAW);

        glBindBuffer(GL_ARRAY_BUFFER, particleBufferB);
        glBufferData(GL_ARRAY_BUFFER, particleCount * sizeof(Particle), particles.data(), GL_DYNAMIC_DRAW);

        particleReadBuffer = particleBufferA;
        particleWriteBuffer = particleBufferB;

        glBindBuffer(GL_ARRAY_BUFFER, particleReadBuffer);
        glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, sizeof(Particle), (void*)0);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, sizeof(Particle), (void*)(sizeof(float) * 4));
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE, sizeof(Particle), (void*)(sizeof(float) * 8));
        glEnableVertexAttribArray(2);
        glDisableVertexAttribArray(3);
    }

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
}

void App::resetParticleState()
{
    if (!particleBufferA || particleCount <= 0)
        return;

    if (particleHasForce)
    {
        struct Particle {
            float position[4];
            float velocity[4];
            float force[4];
            float mass;
            float padding[3];
        };

        std::vector<Particle> particles(particleCount);
        for (int i = 0; i < particleCount; ++i) {
            float t = (float)i / (float)particleCount;
            float angle = t * 6.2831853f * 4.0f;
            float radius = 0.25f + 0.5f * t;
            particles[i].position[0] = radius * cos(angle);
            particles[i].position[1] = radius * sin(angle);
            particles[i].position[2] = 0.0f;
            particles[i].position[3] = 1.0f;
            particles[i].velocity[0] = 0.0f;
            particles[i].velocity[1] = 0.0f;
            particles[i].velocity[2] = 0.0f;
            particles[i].velocity[3] = 0.0f;
            particles[i].force[0] = 0.0f;
            particles[i].force[1] = 0.0f;
            particles[i].force[2] = 0.0f;
            particles[i].force[3] = 0.0f;
            particles[i].mass = 1.0f;
            particles[i].padding[0] = particles[i].padding[1] = particles[i].padding[2] = 0.0f;
        }

        glBindBuffer(GL_ARRAY_BUFFER, particleBufferA);
        glBufferSubData(GL_ARRAY_BUFFER, 0, particleCount * sizeof(Particle), particles.data());
        if (particleBufferB) {
            glBindBuffer(GL_ARRAY_BUFFER, particleBufferB);
            glBufferSubData(GL_ARRAY_BUFFER, 0, particleCount * sizeof(Particle), particles.data());
        }
    }
    else
    {
        struct Particle {
            float position[4];
            float velocity[4];
            float mass;
            float padding[3];
        };

        std::vector<Particle> particles(particleCount);
        for (int i = 0; i < particleCount; ++i) {
            float t = (float)i / (float)particleCount;
            float angle = t * 6.2831853f * 4.0f;
            float radius = 0.25f + 0.5f * t;
            particles[i].position[0] = radius * cos(angle);
            particles[i].position[1] = radius * sin(angle);
            particles[i].position[2] = 0.0f;
            particles[i].position[3] = 1.0f;
            particles[i].velocity[0] = 0.0f;
            particles[i].velocity[1] = 0.0f;
            particles[i].velocity[2] = 0.0f;
            particles[i].velocity[3] = 0.0f;
            particles[i].mass = 1.0f;
            particles[i].padding[0] = particles[i].padding[1] = particles[i].padding[2] = 0.0f;
        }

        glBindBuffer(GL_ARRAY_BUFFER, particleBufferA);
        glBufferSubData(GL_ARRAY_BUFFER, 0, particleCount * sizeof(Particle), particles.data());
        if (particleBufferB) {
            glBindBuffer(GL_ARRAY_BUFFER, particleBufferB);
            glBufferSubData(GL_ARRAY_BUFFER, 0, particleCount * sizeof(Particle), particles.data());
        }
    }

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    particleReadBuffer = particleBufferA;
    particleWriteBuffer = particleBufferB ? particleBufferB : particleBufferA;
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

bool App::savePreset(const std::string& name, const std::string& vertex, const std::string& fragment, const std::string& compute, bool computeEnabled, bool particleModeEnabled, std::string& errorOut) const
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
    metaFile << "useParticleMode=" << (particleModeEnabled ? "1" : "0") << "\n";
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
                } else if (line.rfind("useParticleMode=", 0) == 0) {
                    preset.useParticleMode = (line.substr(16) == "1");
                }
            }
        }
    } else {
        preset.useComputeShader = false;
        preset.useParticleMode = false;
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
        useParticleMode = false;
        compileShader();
        compileComputeShader();
        hintMessage = "New shader created.";
    }
    ImGui::SameLine();
    if (ImGui::Button("Save As")) {
        std::string error;
        if (newPresetName.empty()) {
            hintMessage = "Enter a name before saving.";
        } else if (savePreset(newPresetName, vertexCode, fragmentCode, computeCode, useComputeShader, useParticleMode, error)) {
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
            if (savePreset(selectedPreset, vertexCode, fragmentCode, computeCode, useComputeShader, useParticleMode, error)) {
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
                useParticleMode = loaded.useParticleMode;
                compileShader(true);
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

void App::renderPlaybackBar()
{
    if (!showPlaybackBar) return;

    ImGui::PushFont(uiFont); 

    ImGuiIO& io = ImGui::GetIO();

    // Anchor to bottom of screen
    float barHeight   = 90.0f;
    float barWidth    = io.DisplaySize.x;
    ImGui::SetNextWindowPos(ImVec2(0, io.DisplaySize.y - barHeight), ImGuiCond_Always);
    ImGui::SetNextWindowSize(ImVec2(barWidth, barHeight), ImGuiCond_Always);
    ImGui::SetNextWindowBgAlpha(0.82f);

    ImGuiWindowFlags flags =
        ImGuiWindowFlags_NoDecoration     |
        ImGuiWindowFlags_NoMove           |
        ImGuiWindowFlags_NoSavedSettings  |
        ImGuiWindowFlags_NoBringToFrontOnFocus;

    if (!ImGui::Begin("##PlaybackBar", nullptr, flags))
    {
        ImGui::End();
        return;
    }

    // ── Row 1: Progress bar ──────────────────────────────────────────
    float progress    = (animationDuration > 0.0f)
                        ? std::clamp(simulationTime / animationDuration, 0.0f, 1.0f)
                        : 0.0f;
    float elapsed     = simulationTime;
    float remaining   = animationDuration - elapsed;

    // Time labels  [mm:ss.t] left and right of bar
    auto fmtTime = [](float t) -> std::string {
        t = std::max(t, 0.0f);
        int   m  = (int)(t / 60.0f);
        float s  = fmodf(t, 60.0f);
        char buf[32];
        snprintf(buf, sizeof(buf), "%02d:%05.2f", m, s);
        return buf;
    };

    std::string elapsedStr   = fmtTime(elapsed);
    std::string remainingStr = "-" + fmtTime(remaining);

    float labelW  = ImGui::CalcTextSize("00:00.00").x + 6.0f;
    float remLblW = ImGui::CalcTextSize("-00:00.00").x + 6.0f;
    float barW    = barWidth - labelW - remLblW - 32.0f;

    // Elapsed label
    ImGui::SetCursorPosX(8.0f);
    ImGui::TextUnformatted(elapsedStr.c_str());
    ImGui::SameLine();

    // --- Clickable / draggable progress bar ---
    ImVec2 barMin = ImVec2(ImGui::GetCursorScreenPos().x, ImGui::GetCursorScreenPos().y + 2.0f);
    ImVec2 barMax = ImVec2(barMin.x + barW, barMin.y + 16.0f);

    ImDrawList* drawList = ImGui::GetWindowDrawList();

    // Track background
    drawList->AddRectFilled(barMin, barMax, IM_COL32(60, 60, 60, 255), 6.0f);
    // Filled portion
    float fillX = barMin.x + barW * progress;
    drawList->AddRectFilled(barMin, ImVec2(fillX, barMax.y), IM_COL32(80, 180, 255, 255), 6.0f);
    // Thumb
    drawList->AddCircleFilled(ImVec2(fillX, (barMin.y + barMax.y) * 0.5f), 8.0f, IM_COL32(255, 255, 255, 230));

    // Invisible button to capture clicks & drags
    ImGui::SetCursorScreenPos(ImVec2(barMin.x, barMin.y - 4.0f));
    ImGui::InvisibleButton("##progressbar", ImVec2(barW, 24.0f));

    if (ImGui::IsItemActive())   // click or drag
    {
        float mouseX    = io.MousePos.x;
        float t         = (mouseX - barMin.x) / barW;
        t               = std::clamp(t, 0.0f, 1.0f);
        simulationTime  = t * animationDuration;
    }

    // Remaining label
    ImGui::SameLine();
    ImGui::SetCursorPosX(barMin.x + barW + 8.0f);
    ImGui::TextUnformatted(remainingStr.c_str());

    // ── Row 2: Transport buttons ─────────────────────────────────────
    ImGui::Spacing();

    float btnW = 38.0f;
    float totalBtns = btnW * 6 + ImGui::GetStyle().ItemSpacing.x * 5;
    ImGui::SetCursorPosX((barWidth - totalBtns) * 0.5f);

    // ⏮  Rewind to start
    if (ImGui::Button("\xef\x81\x88##rew", ImVec2(btnW, 0)))
    if (ImGui::Button("Rewind to Start##rew", ImVec2(btnW, 0)))
    {
        simulationTime = 0.0f;
        isPlaying      = false;
    }
    ImGui::SetItemTooltip("Rewind to start");
    ImGui::SameLine();

    // ⏪  Hold to rewind
    // Reset flags here — previous frame's values already drove the time advance above
    isFastForwarding = false;
    isRewinding      = false;

    bool rwHeld = ImGui::Button("\xef\x81\x89##rw", ImVec2(btnW, 0));
    ImGui::SetItemTooltip("Hold: rewind  |  Click: step -1s");
    if (ImGui::IsItemActive() && ImGui::IsMouseDown(0))
        isRewinding = true;
    else if (rwHeld && !isRewinding)
        simulationTime = std::max(simulationTime - 1.0f, 0.0f);
    ImGui::SameLine();

    // ⏯  Play / Pause
    const char* playLabel = isPlaying ? "\xef\x81\x8c##pp" : "\xef\x81\x8b##pp";
    if (ImGui::Button(playLabel, ImVec2(btnW, 0)))
        isPlaying = !isPlaying;
    ImGui::SetItemTooltip(isPlaying ? "Pause" : "Play");
    ImGui::SameLine();

    // ⏩  Hold to fast-forward
    bool ffHeld = ImGui::Button("\xef\x81\x90##ff", ImVec2(btnW, 0));
    ImGui::SetItemTooltip("Hold: fast-forward  |  Click: step +1s");
    if (ImGui::IsItemActive() && ImGui::IsMouseDown(0))
        isFastForwarding = true;
    else if (ffHeld && !ImGui::IsItemActive())
        simulationTime = std::min(simulationTime + 1.0f, animationDuration);
    ImGui::SameLine();

    // ⏭  Jump to end
    if (ImGui::Button("\xef\x81\x91##end", ImVec2(btnW, 0)))
    {
        simulationTime = animationDuration;
        isPlaying      = false;
    }
    ImGui::SetItemTooltip("Jump to end");
    ImGui::SameLine();

    // 🔁  Loop toggle
    ImGui::PushStyleColor(ImGuiCol_Button,
        loopAnimation ? IM_COL32(40, 130, 200, 200) : IM_COL32(60, 60, 60, 200));
    if (ImGui::Button("\xef\x81\xb9##loop", ImVec2(btnW, 0)))
        loopAnimation = !loopAnimation;
    ImGui::PopStyleColor();
    ImGui::SetItemTooltip(loopAnimation ? "Loop ON  (click to disable)" : "Loop OFF (click to enable)");

    // ── Row 2 extras: speed & duration ──────────────────────────────
    ImGui::SameLine(0.0f, 24.0f);
    ImGui::Checkbox("Reset time on compile", &resetTimeOnCompile);
    ImGui::SetItemTooltip(
        "ON  -> simulationTime resets to 0 on every successful compile\n"
        "OFF -> simulationTime continues from where it was (accumulated offset)");

    ImGui::SameLine(0.0f, 16.0f);
    ImGui::Checkbox("Logo as iChannel0", &useLogoAsChannel0);
    ImGui::SetItemTooltip(
        "ON  -> iChannel0 samples the logo texture (the 'after-error' look)\n"
        "OFF -> iChannel0 is unbound, returns black (the clean compile look)");

    ImGui::SameLine(0.0f, 24.0f);
    ImGui::SetNextItemWidth(130.0f);
    ImGui::SliderFloat("Speed##speed", &simulationSpeed, 0.1f, 10000.0f, "Speed %.2fx", ImGuiSliderFlags_Logarithmic);
    ImGui::SetItemTooltip("Simulation speed (logarithmic). Ctrl+Click to type a value. Shared with Compute panel.");

    ImGui::SameLine();
    ImGui::SetNextItemWidth(100.0f);
    ImGui::SliderFloat("Duration##dur", &animationDuration, 5.0f, 3600.0f, "%.0fs");
    ImGui::SetItemTooltip("Total animation duration (seconds)");

    ImGui::SameLine();
    ImGui::SetNextItemWidth(80.0f);
    ImGui::SliderFloat("Fast-Forward Rate##ffrate", &fastForwardRate, 2.0f, 32.0f, "FF %.0fx");
    ImGui::SetItemTooltip("Fast-forward / rewind multiplier");

    ImGui::End();

    ImGui::PopFont(); 
}

void App::renderScene()
{
    if (windowWidth <= 0 || windowHeight <= 0)
        return;

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, windowWidth, windowHeight);

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

        bool renderOk = shaderValid;
    if (useComputeShader)
    {
        renderOk = renderOk && computeValid;
    }

        // --- High Speed Simulation Catch-up ---
    // Only run the iterative sub-stepping engine for texture simulations (MOSFET, Game of Life)
    // Particle simulations (N-Body) should use the standard single-pass logic below.
    if (renderOk && useComputeShader && useIterativeEngine)
    {
        // Handle Rewind/Reset for iterative engine
        if (simulationTime < internalSimTime)
        {
            internalSimTime = 0.0f;
            needInitDispatch = true;
            needsPingPongInit = true;
        }

        bool isMoving = isPlaying || isFastForwarding || isRewinding;

        if (isMoving && simulationTime > internalSimTime)
        {
            float stepSize = 0.016f; 
            int maxStepsPerFrame = (simulationSpeed > 100.0f) ? 20 : 1;
            if (simulationSpeed > 300.0f) maxStepsPerFrame = 60;
            
            // If the jump is massive (manual scrub), cap steps but move internalSimTime
            if (simulationTime - internalSimTime > 1.0f) {
                internalSimTime = simulationTime - 0.5f;
            }

            int stepsPerformed = 0;
            while (internalSimTime < simulationTime && stepsPerformed < maxStepsPerFrame)
            {
                if (usePingPong)
                {
                     if (needsPingPongInit || (useDualComputeShader && needInitDispatch))
                    {
                        if (useR8UIPingPong) seedPingPongTexture(pingPongReadTex, windowWidth, windowHeight);
                        else if (useDualComputeShader && initComputeValid)
                        {
                            initComputeShader.use();
                            initComputeShader.setFloat("uTime", internalSimTime);
                            initComputeShader.setVec2("uResolution", (float)windowWidth, (float)windowHeight);
                            initComputeShader.setFloat("gateVoltage", gateVoltage);
                            glBindImageTexture(0, pingPongReadTex, 0, GL_FALSE, 0, GL_WRITE_ONLY, useR8UIPingPong ? GL_R8UI : GL_RGBA32F);
                            glDispatchCompute(((GLuint)windowWidth + 15) / 16, ((GLuint)windowHeight + 15) / 16, 1);
                            glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
                        }
                        needsPingPongInit = false;
                        needInitDispatch = false;
                    }

                    computeShader.use();
                    computeShader.setFloat("uTime", internalSimTime);
                    computeShader.setVec2("uResolution", (float)windowWidth, (float)windowHeight);
                    computeShader.setFloat("dt", stepSize);
                    computeShader.setFloat("gateVoltage", gateVoltage);
                    computeShader.setFloat("time", internalSimTime);

                    GLenum format = useR8UIPingPong ? GL_R8UI : GL_RGBA32F;
                    glBindImageTexture(0, pingPongReadTex,  0, GL_FALSE, 0, GL_READ_ONLY,  format);
                    glBindImageTexture(1, pingPongWriteTex, 0, GL_FALSE, 0, GL_WRITE_ONLY, format);

                    int lx = parseLocalSize(computeCode, "x", 16);
                    int ly = parseLocalSize(computeCode, "y", 16);
                    glDispatchCompute(((GLuint)windowWidth + lx - 1) / lx, ((GLuint)windowHeight + ly - 1) / ly, 1);
                    glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
                    std::swap(pingPongReadTex, pingPongWriteTex);
                }
                
                internalSimTime += stepSize;
                stepsPerformed++;
            }
        }
    }

    if (useParticleMode)
    {
        if (renderOk && particleCount > 0 && particleVAO != 0)
        {
            if (useComputeShader)
            {
                if (useDualComputeShader && needInitDispatch)
                {
                    int initInvocationCount = getComputeShaderLocalInvocationCount(splitCombinedShaderSources(computeCode).computeSources.initSource);
                    int initDispatchCount = (particleCount + initInvocationCount - 1) / initInvocationCount;

                    initComputeShader.use();
                    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, particleReadBuffer);
                    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, particleWriteBuffer);
                    initComputeShader.setFloat("uTime", simulationTime);
                    initComputeShader.setVec2("uResolution", (float)windowWidth, (float)windowHeight);
                    initComputeShader.setFloat("dt", computeDt);
                    initComputeShader.setVec3("gravityCenter", 0.0f, 0.0f, 0.0f);
                    initComputeShader.setFloat("gravityIntensity", 1.0f);
                    initComputeShader.setFloat("k", 0.1f);
                    initComputeShader.setInt("increaseK", 0);
                    glDispatchCompute((GLuint)initDispatchCount, 1, 1);
                    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT | GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT);
                    std::swap(particleReadBuffer, particleWriteBuffer);
                    needInitDispatch = false;
                }

                    {
                        int updateInvocationCount = getComputeShaderLocalInvocationCount(splitCombinedShaderSources(computeCode).computeSources.updateSource);
                        int updateDispatchCount = (particleCount + updateInvocationCount - 1) / updateInvocationCount;

                        computeShader.use();
                        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, particleReadBuffer);
                        GLuint writeBuffer = particleWriteBuffer ? particleWriteBuffer : particleReadBuffer;
                        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, writeBuffer);
                        computeShader.setFloat("uTime", simulationTime);
                        computeShader.setVec2("uResolution", (float)windowWidth, (float)windowHeight);
                        computeShader.setVec3("gravityCenter", 0.0f, 0.0f, 0.0f);
                        computeShader.setFloat("gravityIntensity", 1.0f);
                        computeShader.setFloat("k", 0.1f);
                        computeShader.setInt("increaseK", 0);
                    
                        // N-Body should always use the current simulation frame's dt
                        computeShader.setFloat("dt", computeDt);
                    
                        glDispatchCompute((GLuint)updateDispatchCount, 1, 1);
                        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT | GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT);
                    
                        bool isMoving = isPlaying || isFastForwarding || isRewinding;
                        if (particleWriteBuffer && particleWriteBuffer != particleReadBuffer && isMoving)
                            std::swap(particleReadBuffer, particleWriteBuffer);
                    }

                GLenum err = glGetError();
                if (err != GL_NO_ERROR)
                {
                    std::cerr << "GL ERROR after compute: " << err << std::endl;
                }
            }

            shader.use();
            shader.setMat4("viewProjection", glm::mat4(1.0f));
            shader.setVec3("baseColor", 1.0f, 1.0f, 1.0f);
            shader.setFloat("uTime", simulationTime);
            shader.setVec2("uResolution", (float)windowWidth, (float)windowHeight);
            shader.setVec2("uMouse", 0.0f, 0.0f);
            shader.setFloat("dt", computeDt);

            glBindVertexArray(particleVAO);
            glBindBuffer(GL_ARRAY_BUFFER, particleReadBuffer);
            if (particleHasForce)
            {
                const GLsizei stride = sizeof(float) * 16;
                glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, stride, (void*)0);
                glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, stride, (void*)(sizeof(float) * 4));
                glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, stride, (void*)(sizeof(float) * 8));
                glVertexAttribPointer(3, 1, GL_FLOAT, GL_FALSE, stride, (void*)(sizeof(float) * 12));
            }
            else
            {
                const GLsizei stride = sizeof(float) * 12;
                glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, stride, (void*)0);
                glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, stride, (void*)(sizeof(float) * 4));
                glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE, stride, (void*)(sizeof(float) * 8));
                glDisableVertexAttribArray(3);
            }
            glBindBuffer(GL_ARRAY_BUFFER, 0);
            glDrawArrays(GL_POINTS, 0, particleCount);
            glBindVertexArray(0);
            return;
        }
    }

    if (windowWidth <= 0 || windowHeight <= 0)
        return;

    glBindVertexArray(VAO);

    if (renderOk)
    {
        if (useComputeShader)
        {
            if (usePingPong)
            {
                // ---- Generic ping-pong path (r8ui or rgba32f) ----
                // Note: The main simulation loop above now handles the high-speed steps.
                // This section now only handles the render pass setup.

                // Render pass
                shader.use();
                if (useR8UIPingPong)
                {
                    glBindImageTexture(0, pingPongReadTex, 0, GL_FALSE, 0, GL_READ_ONLY, GL_R8UI);
                    shader.setVec2("resolution", (float)windowWidth, (float)windowHeight);
                }
                else
                {
                    glActiveTexture(GL_TEXTURE0);
                    glBindTexture(GL_TEXTURE_2D, pingPongReadTex);
                    shader.setInt("densityTex", 0);
                    shader.setInt("iChannel0", 0);
                }
                shader.setFloat("uTime",     simulationTime);
                shader.setFloat("dt", computeDt);
                shader.setFloat("gateVoltage", gateVoltage);
            }
            else
            {
                // ---- standard rgba32f compute path ----
                CombinedShaderSources combined = splitCombinedShaderSources(computeCode);
                const std::string& updateSrc = combined.computeSources.updateSource;

                computeShader.use();
                bool bindComputeTextureToBoth = computeSourceUsesWriteBinding1(updateSrc);
                if (bindComputeTextureToBoth)
                {
                    glBindImageTexture(0, computeTexture, 0, GL_FALSE, 0, GL_READ_ONLY,  GL_RGBA32F);
                    glBindImageTexture(1, computeTexture, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F);
                }
                else
                {
                    glBindImageTexture(0, computeTexture, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F);
                }

                computeShader.setFloat("uTime", simulationTime);
                computeShader.setVec2("uResolution", (float)windowWidth, (float)windowHeight);
                computeShader.setVec3("gravityCenter", 0.0f, 0.0f, 0.0f);
                computeShader.setFloat("gravityIntensity", 1.0f);
                computeShader.setFloat("k", 0.1f);
                computeShader.setInt("increaseK", 0);
                computeShader.setFloat("dt", computeDt);

                // Default tone-mapping parameters for shaders that expect them.
                computeShader.setFloat("exposure", 1.0f);
                computeShader.setFloat("white", 1.0f);
                computeShader.setInt("toneMappingType", 2);
                computeShader.setInt("toneMappingOnRGB", 1);
                computeShader.setFloat("gamma", 2.2f);

                glDispatchCompute(
                    (GLuint)(windowWidth  + 15) / 16,
                    (GLuint)(windowHeight + 15) / 16,
                    1
                );
                glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT | GL_TEXTURE_FETCH_BARRIER_BIT);

                GLenum err = glGetError();
                if (err != GL_NO_ERROR)
                    std::cerr << "GL ERROR after compute: " << err << std::endl;

                // Display the rgba32f texture via the blit shader
                displayShader.use();
                displayShader.setInt("uTexture", 0);
                glActiveTexture(GL_TEXTURE0);
                glBindTexture(GL_TEXTURE_2D, computeTexture);
            }
        }
        else
        {
            shader.use();
            shader.setFloat("uTime", simulationTime);
            shader.setVec2("uResolution", (float)windowWidth, (float)windowHeight);
            shader.setVec2("uMouse", 0.0f, 0.0f);
            shader.setFloat("dt", computeDt);
            shader.setInt("iChannel0", 0);
            glActiveTexture(GL_TEXTURE0);
            if (useLogoAsChannel0 && logoLoaded && logoTexture != 0)
                glBindTexture(GL_TEXTURE_2D, logoTexture);
            else
                glBindTexture(GL_TEXTURE_2D, 0);
        }

        glDrawArrays(GL_TRIANGLES, 0, 6);
    }
    else
    {
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