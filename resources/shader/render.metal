#include <metal_stdlib>
using namespace metal;

// Define a structure for vertex data (position and color)
struct Vertex {
    float2 position;  // 2D position
    float2 texCoord [[attribute(1)]];
};

// Define the output structure for the vertex function
struct VertexOut {
    float4 position [[position]];  // Transformed position for the vertex
    float2 texCoord;
};

// Vertex shader: transforms vertices and passes color to the fragment stage
vertex VertexOut vertexFunction(uint vid [[vertex_id]], constant Vertex* vertices [[buffer(0)]]) {
    VertexOut out;
    out.position = float4(vertices[vid].position, 0.0, 1.0);  // Convert 2D to 4D vector
    out.texCoord = vertices[vid].texCoord;  // Pass vertex color to the fragment shader
    return out;
}

// Fragment shader: assign color to the fragment
fragment float4 fragmentFunction(VertexOut in [[stage_in]], texture2d<float> inputTexture [[ texture(0) ]]) {
    // Create a linear sampler to sample the texture
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    // Sample the texture at the provided texture coordinates
    float4 texColor = inputTexture.sample(textureSampler, in.texCoord);

    // Return the sampled color
    return float4(texColor.rgb, 1.0);  // Use the texture color (with full alpha)
}
