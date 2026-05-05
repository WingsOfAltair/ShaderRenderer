#pragma once

#include <GLFW/glfw3.h>
#include "shader.h"
#include "editor.h"
#include <filesystem>
#include <string>
#include <vector>
#include <glad/gl.h>

struct ShaderPreset {
    std::string name;
    std::string vertexCode;
    std::string fragmentCode;
    std::string computeCode;
    bool useComputeShader = false;
    bool useParticleMode = false;
};

struct ComputeShaderSources {
    std::string initSource;
    std::string updateSource;
};

struct CombinedShaderSources {
    ComputeShaderSources computeSources;
    std::string vertexSource;
    std::string fragmentSource;
};

class App {
public:
    App();
    ~App();

    bool init(int width, int height, const char* title);
    void run();
    void shutdown();

private:
    void renderUI();
    void renderPlaybackBar();
    void compileShader(bool resetParticles = false);
    bool compileComputeShader(bool showPopup = true);
    void renderScene();
    void updateBuffers();
    void createComputeTexture(int width, int height);
    void destroyComputeTexture();
    ComputeShaderSources splitComputeShaderSources(const std::string& source) const;
    CombinedShaderSources splitCombinedShaderSources(const std::string& source) const;
    bool computeSourceUsesForce(const std::string& source) const;
    bool computeSourceUsesWriteBinding1(const std::string& source) const;
    bool computeSourceUsesR8UI(const std::string& source) const;
    void createPingPongTextures(int width, int height);
    void destroyPingPongTextures();
    void seedPingPongTexture(GLuint tex, int width, int height);
    int getComputeShaderLocalInvocationCount(const std::string& source) const;
    void createParticleBuffers(int count);
    void resetParticleState();
    void destroyParticleBuffers();
    void renderSavedShadersWindow();
    std::vector<ShaderPreset> getPresets() const;
    std::filesystem::path getShadersFolder() const;
    std::string makeSafePresetName(const std::string& name) const;
    bool savePreset(const std::string& name, const std::string& vertex, const std::string& fragment, const std::string& compute, bool computeEnabled, bool particleModeEnabled, std::string& errorOut) const;
    bool deletePreset(const std::string& name, std::string& errorOut) const;
    bool loadPreset(const std::string& name, ShaderPreset& preset, std::string& errorOut) const;
    static std::string extractFirstShaderStage(const std::string& source);
    void createErrorTexture();
    void loadLogoTexture();
    void createFBO(GLuint& fbo, GLuint& tex);
    void destroyFBO(GLuint& fbo, GLuint& tex);
    void handleResize();
    static std::filesystem::path getExecutableDirectory();
    void requestShutdown();


    // GLFW
    GLFWwindow* window;
    int windowWidth;
    int windowHeight;
    int pendingWidth;
    int pendingHeight;
    bool pendingResize;

    // Shader
    Shader shader;
    Shader computeShader;
    Shader initComputeShader;
    Shader displayShader;
    std::string vertexCode;
    std::string fragmentCode;
    std::string computeCode;
    std::string compileError;
    std::string computeCompileError;
    std::string initComputeCompileError;
    bool shaderValid;
    bool computeValid;
    bool initComputeValid;
    bool useComputeShader;
    bool useParticleMode;
    bool useDualComputeShader;
    bool needInitDispatch;
    bool particleHasForce;
    unsigned int computeTexture;

    // Ping-pong r8ui textures for image-based compute shaders (e.g. Game of Life)
    GLuint pingPongTexA;
    GLuint pingPongTexB;
    GLuint pingPongReadTex;
    GLuint pingPongWriteTex;
    bool usePingPong;           // true when compute uses r8ui or rgba32f ping-pong
    bool useR8UIPingPong;       // specifically for Game of Life style
    bool needsPingPongInit;     // true until first frame seeds random cell data
    bool useIterativeEngine;    // true for texture-based simulations that need sub-stepping
    float gateVoltage;          // MOSFET simulation parameter
    float pingPongAccumulator;  // fractional step accumulator for speed control
    GLuint particleVAO;
    GLuint particleBufferA;
    GLuint particleBufferB;
    GLuint particleReadBuffer;
    GLuint particleWriteBuffer;
        int particleCount;
        float time;
        float simulationTime;       // Playback head time
        float lastSimulationTime;   // To detect rewinding/scrubbing
        float internalSimTime;     // Current time reached by the simulation state
        float lastFrameTime;
        int frameCount;
    float fps;
    float simulationSpeed;
    float computeDt;

        // Playback controls
    bool  isPlaying;
    float animationDuration;
    bool  loopAnimation;
    float fastForwardRate;
    bool  isFastForwarding;
    bool  isRewinding;
    bool  showPlaybackBar;
    bool  resetTimeOnCompile;
    bool  useLogoAsChannel0;

    // Editor
    ShaderEditor vertexEditor;
    ShaderEditor fragmentEditor;
    ShaderEditor computeEditor;

        // UI state
    bool showHelp;
    bool showSavedShaders;
    bool showVertexEditor;
    bool showFragmentEditor;
    bool showComputeEditor;
    float hintTimer;
    bool showHint;
    std::string hintMessage;
    bool showCompileErrorPopup;
    std::string compileErrorPopupMessage;
    float compileErrorPopupTimer;
    std::string selectedPreset;
    std::string newPresetName;

    // File paths
    std::string vertexFilePath;
    std::string fragmentFilePath;
    bool autoReload;

    // VAO/VBO
    unsigned int VAO;
    unsigned int VBO;

    GLuint errorTexture;
    GLuint logoTexture;
    bool logoLoaded = false;

    // Default shaders
    static const char* defaultVertexShader;
    static const char* defaultFragmentShader;
    static const char* testFragmentShader;
    static const char* defaultComputeShader;
    static const char* defaultDisplayVertexShader;
    static const char* defaultDisplayFragmentShader;

    bool forceDebugDraw = false;

    GLuint backgroundFBO = 0;
    GLuint backgroundTex = 0;

    GLuint shaderFBO = 0;
    GLuint shaderTex = 0;

    bool shuttingDown = false;
    bool forceRecompute = false;
    bool framebufferResized = false;

    ImFont* uiFont = nullptr;
};

