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

class App {
public:
    App();
    ~App();

    bool init(int width, int height, const char* title);
    void run();
    void shutdown();

private:
    void renderUI();
    void compileShader();
    bool compileComputeShader(bool showPopup = true);
    void renderScene();
    void updateBuffers();
    void createComputeTexture(int width, int height);
    void destroyComputeTexture();
    void createParticleBuffers(int count);
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
    static std::filesystem::path getExecutableDirectory();
    void requestShutdown();

    // GLFW
    GLFWwindow* window;
    int windowWidth;
    int windowHeight;

    // Shader
    Shader shader;
    Shader computeShader;
    Shader displayShader;
    std::string vertexCode;
    std::string fragmentCode;
    std::string computeCode;
    std::string compileError;
    std::string computeCompileError;
    bool shaderValid;
    bool computeValid;
    bool useComputeShader;
    bool useParticleMode;
    unsigned int computeTexture;
    GLuint particleVAO;
    GLuint particleBuffer;
    int particleCount;
    float time;
    float lastFrameTime;
    int frameCount;
    float fps;

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
};


