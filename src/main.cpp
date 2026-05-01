#include "app.h"
#include <iostream>
#include <cstdlib>

int main()
{
    App app;

    if (!app.init(1280, 720, "Shader Renderer")) {
        std::cerr << "Failed to initialize application" << std::endl;
        return -1;
    }

    app.run();
    app.shutdown();

    // 🔥 FORCE FULL PROCESS EXIT (prevents zombie process)
    std::cout << "Application exited cleanly." << std::endl;
    std::fflush(stdout);

    std::_Exit(0);   // hard termination, no cleanup left hanging
}