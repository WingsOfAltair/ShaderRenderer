#pragma once

#include <string>
#include <unordered_map>
#include <glm/glm.hpp>

class Shader {
public:
    Shader();
    ~Shader();

    bool compile(const std::string& vertexSrc, const std::string& fragmentSrc, std::string& errorOut);
    bool compileCompute(const std::string& computeSrc, std::string& errorOut);
    void use() const;
    void setFloat(const std::string& name, float value) const;
    void setInt(const std::string& name, int value) const;
    void setVec2(const std::string& name, float x, float y) const;
    void setVec3(const std::string& name, float x, float y, float z) const;
    void setVec4(const std::string& name, float x, float y, float z, float w) const;
    void setMat4(const std::string& name, const glm::mat4& value) const;
    int getUniformLocation(const std::string& name) const;

    unsigned int getID() const { return programID; }
    bool isValid() const { return programID != 0; }

private:
    unsigned int programID;
    unsigned int vertexShader;
    unsigned int fragmentShader;
    unsigned int computeShader;
    mutable std::unordered_map<std::string, int> uniformCache;

    void checkCompileErrors(unsigned int shader, const std::string& type);
    int getUniformLocationCached(const std::string& name) const;
};

