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


// Utility function to clamp a value between a minimum and a maximum
float clamp_val(float value, float min_val, float max_val) {
    return clamp(value, min_val, max_val);
}

// Convert RGB to HSL
float3 rgb_to_hsl(float3 rgb) {
    float R = rgb.r;
    float G = rgb.g;
    float B = rgb.b;

    float max_val = max(R, max(G, B));
    float min_val = min(R, min(G, B));
    float delta = max_val - min_val;

    float L = (max_val + min_val) / 2.0;
    float S = 0.0;
    float H = 0.0;

    if (delta != 0.0) {
        // Saturation calculation
        if (L < 0.5) {
            S = delta / (max_val + min_val);
        } else {
            S = delta / (2.0 - max_val - min_val);
        }

        // Hue calculation
        if (max_val == R) {
            H = ((G - B) / delta) + (G < B ? 6.0 : 0.0);
        } else if (max_val == G) {
            H = ((B - R) / delta) + 2.0;
        } else if (max_val == B) {
            H = ((R - G) / delta) + 4.0;
        }

        H *= 60.0;  // Convert to degrees
    }

    return float3(H, S * 100.0, L * 100.0);  // Return H in degrees, S and L in percentages
}

// Convert HSL back to RGB
float3 hsl_to_rgb(float3 hsl) {
    float H = hsl.x;
    float S = hsl.y / 100.0;
    float L = hsl.z / 100.0;

    float C = (1.0 - abs(2.0 * L - 1.0)) * S;
    float H_prime = H / 60.0;
    float X = C * (1.0 - abs(fmod(H_prime, 2.0) - 1.0));

    float3 rgb;

    if (H_prime >= 0.0 && H_prime < 1.0) {
        rgb = float3(C, X, 0.0);
    } else if (H_prime >= 1.0 && H_prime < 2.0) {
        rgb = float3(X, C, 0.0);
    } else if (H_prime >= 2.0 && H_prime < 3.0) {
        rgb = float3(0.0, C, X);
    } else if (H_prime >= 3.0 && H_prime < 4.0) {
        rgb = float3(0.0, X, C);
    } else if (H_prime >= 4.0 && H_prime < 5.0) {
        rgb = float3(X, 0.0, C);
    } else if (H_prime >= 5.0 && H_prime < 6.0) {
        rgb = float3(C, 0.0, X);
    } else {
        rgb = float3(0.0, 0.0, 0.0);
    }

    float m = L - C / 2.0;
    rgb += float3(m, m, m);  // Add the lightness adjustment

    return rgb;
}

// Adjust HSL values (hue shift, saturation shift, lightness shift)
float3 adjust_color_hsl(float3 rgb, float hue_shift, float saturation_shift, float lightness_shift) {
    float3 hsl = rgb_to_hsl(rgb);

    // Adjust H, S, L
    hsl.x = fmod(hsl.x + hue_shift, 360.0);  // Hue shift and wrap around [0, 360]
    hsl.y = clamp_val(hsl.y + saturation_shift, 0.0, 100.0);  // Clamp saturation
    hsl.z = clamp_val(hsl.z + lightness_shift, 0.0, 100.0);  // Clamp lightness

    return hsl_to_rgb(hsl);  // Convert back to RGB
}

// Fragment shader: blends two textures and assigns the blended color to the fragment
fragment float4 fragmentFunction(VertexOut in [[stage_in]],
texture2d<float> tex1 [[texture(0)]],
        texture2d<float> tex2 [[texture(1)]]) {

// Create a linear sampler to sample the textures
constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

// Sample the first texture at the provided texture coordinates (color1)
float4 color1 = tex1.sample(textureSampler, in.texCoord);

// Sample the second texture at the provided texture coordinates (color2)
float2 texSize1 = float2(tex1.get_width(), tex1.get_height());
float2 texSize2 = float2(tex2.get_width(), tex2.get_height());
float2 scaledTexCoord = in.texCoord * texSize1 / texSize2;
float4 color2 = tex2.sample(textureSampler, scaledTexCoord);

// Step 1: Calculate the HSL values of color2
float3 color2HSL = rgb_to_hsl(color2.rgb);

// Step 2: Shift the HSL of color1 based on color2's HSL values (using color2's HSL as the shift)
float3 shiftedColor1 = adjust_color_hsl(color1.rgb, 255.0, 45.0, 45.0);

shiftedColor1 *= color2.rgb;

// Step 3: Mix the shifted color1 with color2
float3 finalColor = color1.rgb * (1 - color2.a) + shiftedColor1 * color2.a;  // Simple 50/50 mix

// Return the final blended color with full opacity (alpha = 1.0)
return float4(finalColor, 1.0);
}