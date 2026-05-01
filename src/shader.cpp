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

bool Shader::compileCompute(const std::string& computeSrc, std::string& errorOut)
{
    if (programID) {
        glDeleteProgram(programID);
        programID = 0;
    }
    uniformCache.clear();

    if (vertexShader) {
        glDeleteShader(vertexShader);
        vertexShader = 0;
    }
    if (fragmentShader) {
        glDeleteShader(fragmentShader);
        fragmentShader = 0;
    }

    if (computeShader) {
        glDeleteShader(computeShader);
        computeShader = 0;
    }

    computeShader = glCreateShader(GL_COMPUTE_SHADER);
    const char* csrc = computeSrc.c_str();
    glShaderSource(computeShader, 1, &csrc, nullptr);
    glCompileShader(computeShader);

    GLint success;
    glGetShaderiv(computeShader, GL_COMPILE_STATUS, &success);
    if (!success) {
        char infoLog[512];
        glGetShaderInfoLog(computeShader, 512, nullptr, infoLog);
        errorOut = "Compute shader compilation failed:\n" + std::string(infoLog);
        glDeleteShader(computeShader);
        computeShader = 0;
        return false;
    }

    programID = glCreateProgram();
    glAttachShader(programID, computeShader);
    glLinkProgram(programID);

    glGetProgramiv(programID, GL_LINK_STATUS, &success);
    if (!success) {
        char infoLog[512];
        glGetProgramInfoLog(programID, 512, nullptr, infoLog);
        errorOut = "Compute shader program linking failed:\n" + std::string(infoLog);
        return false;
    }

    glDetachShader(programID, computeShader);

    errorOut = "";
    return true;
}

void Shader::use() const
{
    glUseProgram(programID);
}

int Shader::getUniformLocation(const std::string& name) const
{
    return getUniformLocationCached(name);
}

void Shader::setFloat(const std::string& name, float value) const
{
    glUniform1f(getUniformLocation(name), value);
}

void Shader::setInt(const std::string& name, int value) const
{
    glUniform1i(getUniformLocation(name), value);
}

void Shader::setVec2(const std::string& name, float x, float y) const
{
    glUniform2f(getUniformLocation(name), x, y);
}

void Shader::setVec3(const std::string& name, float x, float y, float z) const
{
    glUniform3f(getUniformLocation(name), x, y, z);
}

void Shader::setVec4(const std::string& name, float x, float y, float z, float w) const
{
    glUniform4f(getUniformLocation(name), x, y, z, w);
}

void Shader::setMat4(const std::string& name, const glm::mat4& value) const
{
    glUniformMatrix4fv(getUniformLocation(name), 1, GL_FALSE, &value[0][0]);
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


