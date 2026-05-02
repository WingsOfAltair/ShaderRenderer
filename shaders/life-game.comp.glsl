#version 460 core
layout(local_size_x = 8, local_size_y = 8) in;

layout(r8ui, binding = 0) uniform uimage2D cells_in;
layout(r8ui, binding = 1) uniform uimage2D cells_out;

uint getCell(ivec2 p, ivec2 size)
{
    // WRAP AROUND (toroidal world)
    p = (p + size) % size;
    return imageLoad(cells_in, p).x;
}

uint updateCell(ivec2 cell_idx, ivec2 size)
{
    uint current = getCell(cell_idx, size);

    uint alive =
        getCell(cell_idx + ivec2(-1,-1), size) +
        getCell(cell_idx + ivec2(-1, 0), size) +
        getCell(cell_idx + ivec2(-1, 1), size) +
        getCell(cell_idx + ivec2( 0,-1), size) +
        getCell(cell_idx + ivec2( 0, 1), size) +
        getCell(cell_idx + ivec2( 1,-1), size) +
        getCell(cell_idx + ivec2( 1, 0), size) +
        getCell(cell_idx + ivec2( 1, 1), size);

    // Conway's Game of Life
    return uint((current == 1u && (alive == 2u || alive == 3u)) ||
                (current == 0u && alive == 3u));
}

void main()
{
    ivec2 gidx = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(cells_in);

    uint next = updateCell(gidx, size);
    imageStore(cells_out, gidx, uvec4(next));
}