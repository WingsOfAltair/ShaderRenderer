#include "app.h"
#include <iostream>

#ifdef _WIN32
#include <windows.h>
#endif

bool alreadyRunning()
{
    CreateMutexA(NULL, TRUE, "ShaderRendererMutex");
    return GetLastError() == ERROR_ALREADY_EXISTS;
}

int main()
{
#ifdef _WIN32
    // Optional: no console flash / detach cleanly
    FreeConsole();
#endif

    if (alreadyRunning())
        return 0;

    App app;

    if (!app.init(1280, 720, "Shader Renderer")) {
        std::cerr << "Failed to initialize application" << std::endl;
        return -1;
    }

    app.run();

    app.shutdown();

    std::cout << "Application exited cleanly." << std::endl;

    return 0;
}