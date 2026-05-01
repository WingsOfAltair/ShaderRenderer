#pragma once

#include <GLFW/glfw3.h>
#include "shader.h"
#include "editor.h"
#include <filesystem>
#include <string>
#include <vector>

struct ShaderPreset {
    std::string name;
    std::string vertexCode;
    std::string fragmentCode;
    std::string computeCode;
    bool useComputeShader = false;
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
    bool compileComputeShader();
    void renderScene();
    void updateBuffers();
    void createComputeTexture(int width, int height);
    void destroyComputeTexture();
    void renderSavedShadersWindow();
    std::vector<ShaderPreset> getPresets() const;
    std::filesystem::path getShadersFolder() const;
    std::string makeSafePresetName(const std::string& name) const;
    bool savePreset(const std::string& name, const std::string& vertex, const std::string& fragment, const std::string& compute, bool computeEnabled, std::string& errorOut) const;
    bool deletePreset(const std::string& name, std::string& errorOut) const;
    bool loadPreset(const std::string& name, ShaderPreset& preset, std::string& errorOut) const;

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
    unsigned int computeTexture;
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
    std::string selectedPreset;
    std::string newPresetName;

    // File paths
    std::string vertexFilePath;
    std::string fragmentFilePath;
    bool autoReload;

    // VAO/VBO
    unsigned int VAO;
    unsigned int VBO;

    // Default shaders
    static const char* defaultVertexShader;
    static const char* defaultFragmentShader;
    static const char* testFragmentShader;
    static const char* defaultComputeShader;
    static const char* defaultDisplayVertexShader;
    static const char* defaultDisplayFragmentShader;
};

