#include "app.h"
#include <iostream>

#ifdef _WIN32
#include <windows.h>
#include <string>

bool alreadyRunning()
{
    HANDLE hMutex = CreateMutexA(NULL, TRUE, "ShaderRendererMutex");
    return GetLastError() == ERROR_ALREADY_EXISTS;
}

#else

#include <fcntl.h>
#include <unistd.h>
#include <sys/file.h>

bool alreadyRunning()
{
    int fd = open("/tmp/ShaderRenderer.lock", O_CREAT | O_RDWR, 0666);
    if (fd < 0) return false;

    return flock(fd, LOCK_EX | LOCK_NB) == -1;
}

#endif

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