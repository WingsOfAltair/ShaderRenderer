#include "app.h"
#include <iostream>

int main()
{
    App app;

    if (!app.init(1280, 720, "Shader Renderer")) {
        std::cerr << "Failed to initialize application" << std::endl;
        return -1;
    }

    app.run();
    app.shutdown();

    return 0;
}
