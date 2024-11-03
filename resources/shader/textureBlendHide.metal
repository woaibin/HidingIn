#include <metal_stdlib>
using namespace metal;

// Define a structure for vertex data (position and texture coordinates)
struct Vertex {
    float2 position;  // 2D position
    float2 texCoord;  // Texture coordinates
};

// Define the output structure for the vertex function
struct VertexOut {
    float4 position [[position]];  // Transformed position for the vertex
    float2 texCoord;               // Texture coordinates to be passed to the fragment shader
};

// Vertex shader: transforms vertices and passes texture coordinates to the fragment stage
vertex VertexOut vertexFunction(uint vid [[vertex_id]], constant Vertex* vertices [[buffer(0)]]) {
VertexOut out;
out.position = float4(vertices[vid].position, 0.0, 1.0);  // Convert 2D to 4D vector
out.texCoord = vertices[vid].texCoord;                    // Pass texture coordinates to the fragment shader
return out;
}

// Fragment shader: blends two textures and assigns the blended color to the fragment
fragment float4 fragmentFunction(VertexOut in [[stage_in]],
texture2d<float> tex1 [[texture(0)]],
        texture2d<float> tex2 [[texture(1)]]) {

// Create a linear sampler to sample the textures
constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

// Sample the first texture at the provided texture coordinates
float4 color1 = tex1.sample(textureSampler, in.texCoord);

// Sample the second texture at the provided texture coordinates
// Assuming tex2 may have a different size, we scale the texCoord to match tex2's dimensions
float2 texSize1 = float2(tex1.get_width(), tex1.get_height());
float2 texSize2 = float2(tex2.get_width(), tex2.get_height());
float2 scaledTexCoord = in.texCoord * texSize1 / texSize2;
float4 color2 = tex2.sample(textureSampler, scaledTexCoord);

// Blend the two colors (e.g., by averaging them)
float4 blendedColor = clamp(color1 + color2, 0.0, 1.0);

// Return the blended color
return float4(blendedColor.rgb, 1.0);  // Set the alpha to 1.0 (fully opaque)
}