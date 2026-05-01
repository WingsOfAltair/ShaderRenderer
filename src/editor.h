#pragma once

#include <string>
#include <vector>
#include <functional>
#include <imgui/imgui.h>

enum class TokenType {
    Default,
    Keyword,
    Type,
    Comment,
    Number,
    String,
    Punctuation
};

struct HighlightedToken {
    int start;
    int length;
    TokenType type;
};

struct HighlightedLine {
    std::vector<HighlightedToken> tokens;
};

class ShaderEditor {
public:
    ShaderEditor();
    ~ShaderEditor();

    void render(const char* title, ImVec2 size, std::string& code,
                const std::string& error, int errorLine, bool& changed);
    
    bool loadFile(const char* path, std::string& code);
    bool saveFile(const char* path, const std::string& code);
    
    const std::string& getError() const { return error; }
    int getErrorLine() const { return errorLine; }

    void setAutoReload(bool enabled);
    bool getAutoReload() const;
    int getLineAtY(const std::string& code, float y, float lineHeight) const;
    int getCharAtX(const std::string& code, int line, float x, float charWidth) const;

private:
    void renderEditor(const char* title, ImVec2 size, std::string& code,
                      const std::string& error, int errorLine, bool& changed);
    std::vector<HighlightedLine> highlightSyntax(const std::string& code) const;
    ImVec4 getTokenColor(TokenType type) const;

    std::string error;
    int errorLine;
    ImGuiTextBuffer textBuffer;
    int cursorPos;
    int scrollPos;

    static ImVec4 colors[16];
    static int colorCount;
    static const char* keyWords[];
    static const char* types[];
    static const char* builtins[];
    static int keyWordCount;
    static int typeCount;
    static int builtinCount;
};

