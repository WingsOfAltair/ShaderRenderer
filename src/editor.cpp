#include "editor.h"
#include <../imgui/imgui.h>
#include <fstream>
#include <sstream>
#include <algorithm>
#include <cstring>
#include <unordered_set>

// Shader keywords
const char* ShaderEditor::keyWords[] = {
    "if", "else", "for", "while", "do", "return", "break", "continue",
    "switch", "case", "default", "struct", "class", "uniform", "varying",
    "in", "out", "inout", "layout", "const", "attribute", "varying",
    "precision", "mediump", "lowp", "highp", "discard", "true", "false",
    "gl_FragCoord", "gl_FragColor", "gl_Position", "gl_PointSize",
    nullptr
};

const char* ShaderEditor::types[] = {
    "float", "int", "uint", "bool", "vec2", "vec3", "vec4",
    "mat2", "mat3", "mat4", "sampler2D", "sampler3D", "samplerCube",
    "void", "double", "bvec2", "bvec3", "bvec4", "ivec2", "ivec3", "ivec4",
    nullptr
};

const char* ShaderEditor::builtins[] = {
    "texture", "texture2D", "texture3D", "textureCube",
    "mix", "step", "smoothstep", "clamp", "min", "max", "abs",
    "sign", "floor", "ceil", "round", "fract", "mod", "isnan", "isinf",
    "sqrt", "rsqrt", "inversesqrt", "exp", "log", "exp2", "log2",
    "sin", "cos", "tan", "asin", "acos", "atan", "pow", "length",
    "distance", "dot", "cross", "normalize", "faceforward", "reflect",
    "refract", "matrixCompMult", "transpose", "determinant", "inverse",
    "gl_FragColor", "gl_FragCoord", "gl_Position", "gl_PointSize",
    nullptr
};

int ShaderEditor::keyWordCount = 0;
int ShaderEditor::typeCount = 0;
int ShaderEditor::builtinCount = 0;

ShaderEditor::ShaderEditor()
{
    // Count array sizes
    for (int i = 0; keyWords[i] != nullptr; i++) keyWordCount++;
    for (int i = 0; types[i] != nullptr; i++) typeCount++;
    for (int i = 0; builtins[i] != nullptr; i++) builtinCount++;
}

ShaderEditor::~ShaderEditor() = default;

void ShaderEditor::render(const char* title, ImVec2 size, std::string& code,
                          const std::string& error, int errorLine, bool& changed)
{
    ImGui::SetNextWindowPos(ImVec2(10, 60), ImGuiCond_Always);
    ImGui::SetNextWindowSize(size, ImGuiCond_Always);
    ImGui::Begin(title, nullptr, ImGuiWindowFlags_NoCollapse);
    
    ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), title);
    ImGui::Separator();

    // Highlight code
    auto lines = highlightSyntax(code);
    
    // Render highlighted text
    float charWidth = 8.0f;
    float lineHeight = 16.0f;
    float editorWidth = size.x - 20;
    float editorHeight = size.y - 120;
    
    // Calculate visible range
    int totalLines = 0;
    for (char c : code) if (c == '\n') totalLines++;
    totalLines++;
    
    int visibleLines = static_cast<int>(editorHeight / lineHeight);
    int maxScroll = std::max(0, totalLines - visibleLines);
    
    // Draw background
    ImVec2 winPos = ImGui::GetWindowPos();
    ImVec2 winSize = ImGui::GetWindowSize();
    ImDrawList* drawList = ImGui::GetWindowDrawList();
    
    drawList->AddRectFilled(
        ImVec2(winPos.x + 5, winPos.y + 10),
        ImVec2(winPos.x + winSize.x - 5, winPos.y + winSize.y - 115),
        IM_COL32(25, 25, 30, 255)
    );
    
    // Draw error line highlight
    if (errorLine > 0 && errorLine <= totalLines) {
        float errorY = winPos.y + 10 + (errorLine - 1) * lineHeight;
        drawList->AddRectFilled(
            ImVec2(winPos.x + 5, errorY),
            ImVec2(winPos.x + winSize.x - 5, errorY + lineHeight),
            IM_COL32(255, 80, 80, 80)
        );
    }
    
    // Draw text with line numbers
    for (int i = 0; i < totalLines && i < static_cast<int>(lines.size()); i++) {
        float y = winPos.y + 10 + i * lineHeight;
        
        // Line number
        char lineNum[8];
        snprintf(lineNum, sizeof(lineNum), "%3d | ", i + 1);
        drawList->AddText(ImVec2(winPos.x + 8, y), IM_COL32(100, 100, 100, 255), lineNum);
        
        // Code with syntax highlighting
        if (i < static_cast<int>(lines.size()) && !lines[i].tokens.empty()) {
            float x = winPos.x + 50;
            for (auto& token : lines[i].tokens) {
                // Find actual word length
                int wordLen = 0;
                int pos = token.start;
                while (pos < static_cast<int>(code.size()) && code[pos] != ' ' && code[pos] != '\n' && code[pos] != '\t' && code[pos] != '(' && code[pos] != ')' && code[pos] != '{' && code[pos] != '}' && code[pos] != ';' && code[pos] != ',' && code[pos] != '+' && code[pos] != '-' && code[pos] != '*' && code[pos] != '/' && code[pos] != '=' && code[pos] != '<' && code[pos] != '>' && wordLen < 100) {
                    wordLen++;
                    pos++;
                }
                ImVec4 color = getTokenColor(token.type);
                unsigned int col = IM_COL32(
                    static_cast<unsigned int>(color.x * 255),
                    static_cast<unsigned int>(color.y * 255),
                    static_cast<unsigned int>(color.z * 255),
                    static_cast<unsigned int>(color.w * 255)
                );
                drawList->AddText(ImVec2(x, y), col, code.substr(token.start, wordLen).c_str());
                x += wordLen * charWidth;
            }
        } else {
            // Get line text
            std::string lineText;
            int lineStart = 0;
            for (int j = 0; j < i; j++) {
                while (lineStart < static_cast<int>(code.size()) && code[lineStart] != '\n') lineStart++;
                lineStart++;
            }
            int lineEnd = lineStart;
            while (lineEnd < static_cast<int>(code.size()) && code[lineEnd] != '\n') lineEnd++;
            lineText = code.substr(lineStart, lineEnd - lineStart);
            float x = winPos.x + 50;
            drawList->AddText(ImVec2(x, y), IM_COL32(200, 200, 200, 255), lineText.c_str());
        }
    }
    
    // Render actual editable text with syntax highlighting overlay
    static char textBuf[65536] = "";
    if (ImGui::IsWindowAppearing()) {
        strncpy(textBuf, code.c_str(), sizeof(textBuf) - 1);
        textBuf[sizeof(textBuf) - 1] = '\0';
    }
    
    // Draw the actual editable text on top
    ImGui::SetCursorPos(ImVec2(5, 10));
    ImGui::PushStyleColor(ImGuiCol_ChildBg, ImVec4(0, 0, 0, 0));
    ImGui::BeginChild("editor", ImVec2(size.x - 10, editorHeight), true);
    ImGui::PushFont(ImGui::GetIO().Fonts->Fonts[0]); // Use monospace font
    ImGui::InputTextMultiline("##code", textBuf, IM_ARRAYSIZE(textBuf), ImVec2(-1, -1), ImGuiInputTextFlags_None);
    ImGui::PopFont();
    ImGui::EndChild();
    ImGui::PopStyleColor();
    
    // Update code from buffer
    code = textBuf;
    
    // Compile button
    if (ImGui::Button("Compile (F5)", ImVec2(-1, 0))) {
        changed = true;
    }
    ImGui::SameLine();
    if (ImGui::Button("Save As...", ImVec2(-1, 0))) {
        // Open file dialog
    }
    ImGui::SameLine();
    if (ImGui::Button("Load...", ImVec2(-1, 0))) {
        // Open file dialog
    }
    
    // Show error
    if (!error.empty()) {
        ImGui::Separator();
        ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "Error:");
        ImGui::TextWrapped("%s", error.c_str());
    }
    
    ImGui::End();
}

std::vector<HighlightedLine> ShaderEditor::highlightSyntax(const std::string& code) const
{
    std::vector<HighlightedLine> lines;
    std::string currentLine;
    
    for (char c : code) {
        if (c == '\n') {
            HighlightedLine line;
            
            // Tokenize the line
            int i = 0;
            while (i < static_cast<int>(currentLine.size())) {
                // Skip whitespace
                if (currentLine[i] == ' ' || currentLine[i] == '\t') {
                    i++;
                    continue;
                }
                
                // Single-line comment
                if (i + 1 < static_cast<int>(currentLine.size()) && currentLine[i] == '/' && currentLine[i+1] == '/') {
                    line.tokens.push_back({i, static_cast<int>(currentLine.size()) - i, TokenType::Comment});
                    break;
                }
                
                // Multi-line comment start
                if (i + 1 < static_cast<int>(currentLine.size()) && currentLine[i] == '/' && currentLine[i+1] == '*') {
                    line.tokens.push_back({i, 2, TokenType::Comment});
                    i += 2;
                    while (i + 1 < static_cast<int>(currentLine.size()) && !(currentLine[i] == '*' && currentLine[i+1] == '/')) {
                        i++;
                    }
                    if (i + 1 < static_cast<int>(currentLine.size())) i += 2;
                    continue;
                }
                
                // String literal
                if (currentLine[i] == '"') {
                    int start = i;
                    i++;
                    while (i < static_cast<int>(currentLine.size()) && currentLine[i] != '"') {
                        if (currentLine[i] == '\\') i++;
                        i++;
                    }
                    if (i < static_cast<int>(currentLine.size())) i++; // Skip closing quote
                    line.tokens.push_back({start, i - start, TokenType::String});
                    continue;
                }
                
                // Number
                if (isdigit(currentLine[i]) || (currentLine[i] == '.' && i + 1 < static_cast<int>(currentLine.size()) && isdigit(currentLine[i+1]))) {
                    int start = i;
                    while (i < static_cast<int>(currentLine.size()) && (isdigit(currentLine[i]) || currentLine[i] == '.' || currentLine[i] == 'e' || currentLine[i] == 'E' || currentLine[i] == '+' || currentLine[i] == '-')) {
                        i++;
                    }
                    line.tokens.push_back({start, i - start, TokenType::Number});
                    continue;
                }
                
                // Identifier or keyword
                if (isalpha(currentLine[i]) || currentLine[i] == '_') {
                    int start = i;
                    while (i < static_cast<int>(currentLine.size()) && (isalnum(currentLine[i]) || currentLine[i] == '_')) {
                        i++;
                    }
                    std::string word = currentLine.substr(start, i - start);
                    
                    TokenType type = TokenType::Default;
                    for (int j = 0; keyWords[j] != nullptr; j++) {
                        if (word == keyWords[j]) { type = TokenType::Keyword; break; }
                    }
                    if (type == TokenType::Default) {
                        for (int j = 0; types[j] != nullptr; j++) {
                            if (word == types[j]) { type = TokenType::Type; break; }
                        }
                    }
                    if (type == TokenType::Default) {
                        for (int j = 0; builtins[j] != nullptr; j++) {
                            if (word == builtins[j]) { type = TokenType::Type; break; }
                        }
                    }
                    line.tokens.push_back({start, i - start, type});
                    continue;
                }
                
                // Punctuation
                if (strchr("(){}[];,=<>+-*/!&|%^~?:", currentLine[i])) {
                    line.tokens.push_back({i, 1, TokenType::Punctuation});
                    i++;
                    continue;
                }
                
                i++;
            }
            
            lines.push_back(line);
            currentLine.clear();
        } else {
            currentLine += c;
        }
    }
    
    // Add last line if it doesn't end with newline
    if (!currentLine.empty()) {
        HighlightedLine line;
        lines.push_back(line);
    }
    
    return lines;
}

ImVec4 ShaderEditor::getTokenColor(TokenType type) const
{
    switch (type) {
        case TokenType::Keyword: return ImVec4(1.0f, 0.5f, 0.5f, 1.0f); // Red for keywords
        case TokenType::Type: return ImVec4(0.5f, 0.8f, 1.0f, 1.0f); // Blue for types
        case TokenType::Comment: return ImVec4(0.4f, 0.6f, 0.4f, 1.0f); // Green for comments
        case TokenType::Number: return ImVec4(0.8f, 0.8f, 0.3f, 1.0f); // Yellow for numbers
        case TokenType::String: return ImVec4(0.5f, 0.9f, 0.5f, 1.0f); // Green for strings
        case TokenType::Punctuation: return ImVec4(0.6f, 0.6f, 0.6f, 1.0f); // Gray for punctuation
        default: return ImVec4(0.9f, 0.9f, 0.9f, 1.0f); // White for default
    }
}

bool ShaderEditor::loadFile(const char* path, std::string& code)
{
    std::ifstream file(path);
    if (!file.is_open()) return false;
    
    std::stringstream buffer;
    buffer << file.rdbuf();
    code = buffer.str();
    return true;
}

bool ShaderEditor::saveFile(const char* path, const std::string& code)
{
    std::ofstream file(path);
    if (!file.is_open()) return false;
    
    file << code;
    return true;
}

void ShaderEditor::setAutoReload(bool enabled)
{
    // Implementation
}

bool ShaderEditor::getAutoReload() const
{
    return false;
}

int ShaderEditor::getLineAtY(const std::string& code, float y, float lineHeight) const
{
    return static_cast<int>(y / lineHeight);
}

int ShaderEditor::getCharAtX(const std::string& code, int line, float x, float charWidth) const
{
    return static_cast<int>(x / charWidth);
}
