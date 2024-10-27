#include <metal_stdlib>
using namespace metal;

kernel void textureBlendHide(texture2d<float, access::read> tex1 [[texture(0)]],
                          texture2d<float, access::read> tex2 [[texture(1)]],
                          texture2d<float, access::write> outputTex [[texture(2)]],
                          uint2 gid [[thread_position_in_grid]]) {

    // Ensure we are within the bounds of the texture
    if (gid.x >= tex1.get_width() || gid.y >= tex1.get_height()) {
        return;
    }
    // Get the dimensions of both textures (tex1 and tex2)
    uint2 texSize1 = uint2(tex1.get_width(), tex1.get_height());
    uint2 texSize2 = uint2(tex2.get_width(), tex2.get_height());
    // Calculate the corresponding position in tex2 based on the relative size difference
    float2 gidTex2Related = float2(gid) * float2(texSize2) / float2(texSize1);

    // Convert the scaled gidTex2Related to integer coordinates to read from tex2
    uint2 tex2Coords = uint2(gidTex2Related);

    // Read the pixel values from both input textures at the current grid index
    float4 color1 = tex1.read(gid);
    float4 color2 = tex2.read(tex2Coords);

    // Average the two colors
    float4 blendedColor = (color1 + color2) * 0.5;

    // Write the blended color to the output texture
    outputTex.write(blendedColor, gid);
}