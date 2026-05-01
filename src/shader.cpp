#include "shader.h"
#include <iostream>
#include <glad/gl.h>

Shader::Shader()
    : programID(0), vertexShader(0), fragmentShader(0), computeShader(0)
{
}

Shader::~Shader()
{
    if (programID) glDeleteProgram(programID);
    if (vertexShader) glDeleteShader(vertexShader);
    if (fragmentShader) glDeleteShader(fragmentShader);
    if (computeShader) glDeleteShader(computeShader);
}

bool Shader::compile(const std::string& vertexSrc, const std::string& fragmentSrc, std::string& errorOut)
{
    // Delete existing program if any
    if (programID) {
        glDeleteProgram(programID);
        programID = 0;
    }
    uniformCache.clear();

    if (computeShader) {
        glDeleteShader(computeShader);
        computeShader = 0;
    }

    // Compile vertex shader
    if (vertexShader) {
        glDeleteShader(vertexShader);
        vertexShader = 0;
    }
    if (fragmentShader) {
        glDeleteShader(fragmentShader);
        fragmentShader = 0;
    }

    vertexShader = glCreateShader(GL_VERTEX_SHADER);
    const char* vsrc = vertexSrc.c_str();
    glShaderSource(vertexShader, 1, &vsrc, nullptr);
    glCompileShader(vertexShader);

    GLint success;
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if (!success) {
        char infoLog[512];
        glGetShaderInfoLog(vertexShader, 512, nullptr, infoLog);
        errorOut = "Vertex shader compilation failed:\n" + std::string(infoLog);
        glDeleteShader(vertexShader);
        vertexShader = 0;
        return false;
    }

    fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    const char* fsrc = fragmentSrc.c_str();
    glShaderSource(fragmentShader, 1, &fsrc, nullptr);
    glCompileShader(fragmentShader);

    glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &success);
    if (!success) {
        char infoLog[512];
        glGetShaderInfoLog(fragmentShader, 512, nullptr, infoLog);
        errorOut = "Fragment shader compilation failed:\n" + std::string(infoLog);
        glDeleteShader(fragmentShader);
        fragmentShader = 0;
        return false;
    }

    programID = glCreateProgram();
    glAttachShader(programID, vertexShader);
    glAttachShader(programID, fragmentShader);
    glLinkProgram(programID);

    glGetProgramiv(programID, GL_LINK_STATUS, &success);
    if (!success) {
        char infoLog[512];
        glGetProgramInfoLog(programID, 512, nullptr, infoLog);
        errorOut = "Shader program linking failed:\n" + std::string(infoLog);
        return false;
    }

    glDetachShader(programID, vertexShader);
    glDetachShader(programID, fragmentShader);

    errorOut = "";
    return true;
}

bool Shader::compileCompute(const std::string& source, std::string& errorOut)
{
    errorOut.clear();

    // Cleanup old program
    if (programID)
    {
        glDeleteProgram(programID);
        programID = 0;
    }

    // ============================
    // CREATE SHADER
    // ============================
    GLuint shader = glCreateShader(GL_COMPUTE_SHADER);

    const char* src = source.c_str();
    glShaderSource(shader, 1, &src, nullptr);
    glCompileShader(shader);

    // ============================
    // CHECK COMPILE
    // ============================
    GLint success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);

    if (!success)
    {
        char log[2048];
        glGetShaderInfoLog(shader, sizeof(log), nullptr, log);

        errorOut = std::string("COMPILE ERROR:\n") + log;

        glDeleteShader(shader);
        return false;
    }

    // ============================
    // CREATE PROGRAM
    // ============================
    programID = glCreateProgram();
    glAttachShader(programID, shader);
    glLinkProgram(programID);

    // shader no longer needed after linking
    glDeleteShader(shader);

    // ============================
    // CHECK LINK
    // ============================
    glGetProgramiv(programID, GL_LINK_STATUS, &success);

    if (!success)
    {
        char log[2048];
        glGetProgramInfoLog(programID, sizeof(log), nullptr, log);

        errorOut = std::string("LINK ERROR:\n") + log;

        glDeleteProgram(programID);
        programID = 0;
        return false;
    }

    return true;
}

void Shader::use() const
{
    if (programID)
        glUseProgram(programID);
}

int Shader::getUniformLocation(const std::string& name) const
{
    return getUniformLocationCached(name);
}

void Shader::setFloat(const std::string& name, float value) const
{
    int loc = getUniformLocation(name);
    if (loc != -1)
        glUniform1f(loc, value);
}

void Shader::setInt(const std::string& name, int value) const
{
    int loc = getUniformLocation(name);
    if (loc != -1)
        glUniform1i(loc, value);
}

void Shader::setVec2(const std::string& name, float x, float y) const
{
    int loc = getUniformLocation(name);
    if (loc != -1)
        glUniform2f(loc, x, y);
}

void Shader::setVec3(const std::string& name, float x, float y, float z) const
{
    int loc = getUniformLocation(name);
    if (loc != -1)
        glUniform3f(loc, x, y, z);
}

void Shader::setVec4(const std::string& name, float x, float y, float z, float w) const
{
    int loc = getUniformLocation(name);
    if (loc != -1)
        glUniform4f(loc, x, y, z, w);
}

void Shader::setMat4(const std::string& name, const glm::mat4& value) const
{
    int loc = getUniformLocation(name);
    if (loc != -1)
        glUniformMatrix4fv(loc, 1, GL_FALSE, &value[0][0]);
}

int Shader::getUniformLocationCached(const std::string& name) const
{
    auto it = uniformCache.find(name);
    if (it != uniformCache.end()) {
        return it->second;
    }
    int loc = glGetUniformLocation(programID, name.c_str());
    uniformCache[std::string(name)] = loc;
    return loc;
}


