A simple cross-platform OpenGL GLSL shader compiler/renderer with certain playback controls and a few example provided shaders to test the app.

Supports various image2d vertex/fragment/compute shaders. Still needs lots of work to make the pipeline support different implementations of shaders.

Tested on Windows 11 Pro 64-bit & Linux Ubuntu 25.10 on a VirtualBox v 7.2.4 r170995 (Qt6.8.0 on Windows Host) VM.

Steps to compile & run on Linux:
Clone repository to a specific path you have permissions to
Navigate with Terminal to project root.
mkdir build && cd build
cmake ..
make
./ShaderRenderer

# Do not forget to install required drivers & dependencies on Linux if it fails to run.