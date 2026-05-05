init #version 430

layout (local_size_x = 16, local_size_y = 16) in;

layout(rgba32f, binding = 0) uniform image2D state;

void main()
{
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    vec2 size = vec2(imageSize(state));
    vec2 uv = vec2(coord) / size;

    float density = 0.0;

    // Source pre-filled with carriers
    if(uv.x < 0.1)
        density = 1.0;

    imageStore(state, coord, vec4(density, 0.0, 0.0, 1.0));
}

update #version 430

layout (local_size_x = 16, local_size_y = 16) in;

// Ping-pong textures
layout(rgba32f, binding = 0) uniform image2D currentState;
layout(rgba32f, binding = 1) uniform image2D nextState;

uniform float dt;
uniform float gateVoltage;
uniform float time;

vec2 size = vec2(imageSize(currentState));

float laplacian(ivec2 coord)
{
    float c = imageLoad(currentState, coord).r;

    float sum = 0.0;
    sum += imageLoad(currentState, coord + ivec2(1,0)).r;
    sum += imageLoad(currentState, coord + ivec2(-1,0)).r;
    sum += imageLoad(currentState, coord + ivec2(0,1)).r;
    sum += imageLoad(currentState, coord + ivec2(0,-1)).r;

    return sum - 4.0 * c;
}

void main()
{
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);

    if(coord.x >= int(size.x) || coord.y >= int(size.y))
        return;

    vec2 uv = vec2(coord) / size;

    float density = imageLoad(currentState, coord).r;

    // --- Regions ---
    float source = smoothstep(0.0, 0.1, uv.x);
    float drain  = smoothstep(1.0, 0.9, uv.x);

    float gateRegion = smoothstep(0.3, 0.4, uv.y) *
                       smoothstep(0.7, 0.6, uv.y);

    // --- Physics Approximation ---
    float diffusion = 0.2 * laplacian(coord);

    // Gate attracts carriers
    float gateEffect = gateVoltage * gateRegion * (1.0 - density);

    // Drift toward drain
    float drift = (drain - source) * 0.3 * density;

    float newDensity = density + dt * (diffusion + gateEffect + drift);

    // Clamp physically
    newDensity = clamp(newDensity, 0.0, 1.0);

    imageStore(nextState, coord, vec4(newDensity, 0.0, 0.0, 1.0));
}