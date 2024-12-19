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

// Adjust HSL values to stand out in the environment (enhance contrast)
float3 adjust_hsl_to_stand_out_in_environment(float3 envColor, float3 baseColor) {
    // Step 1: Convert both envColor and baseColor to HSL
    float3 envHSL = rgb_to_hsl(envColor);
    float3 baseHSL = rgb_to_hsl(baseColor);

    // Step 2: Define thresholds for lightness categories
    const float specularThreshold = 75.0;  // High light (specular)
    const float diffuseThreshold = 45.0;   // Mid light (diffuse)
    const float lowLightThreshold = 25.0;  // Low light

    // Step 3: Adjust environment lightness for contrast
    if (envHSL.z > specularThreshold) {
        // If environment is specular (high light), reduce lightness to low light
        envHSL.z = clamp_val(envHSL.z - lowLightThreshold * 0.4, 0.0, 100.0);
        // Step 4: Slightly adjust the hue
        const float hueAdjustment = 18.0;  // Adjust hue by 5 degrees (or any small value)
        envHSL.x = fmod(envHSL.x + hueAdjustment, 360.0);  // Ensure the hue wraps around [0, 360]
    } else if (envHSL.z < lowLightThreshold) {
        // If environment is in low light, increase it to the high light range
        envHSL.z = clamp_val(envHSL.z + specularThreshold * 0.30, 0.0, 100.0);
        // Step 4: Slightly adjust the hue
        const float hueAdjustment = 25.0;  // Adjust hue by 5 degrees (or any small value)
        envHSL.x = fmod(envHSL.x + hueAdjustment, 360.0);  // Ensure the hue wraps around [0, 360]
    } else {
        // If environment is mid light, make a subtle adjustment to increase contrast
        if (envHSL.z > diffuseThreshold) {
            envHSL.z = clamp_val(lowLightThreshold + (envHSL.z - specularThreshold) * 0.7, 0.0, 100.0);  // Slightly increase lightness
        } else {
            envHSL.z = clamp_val(specularThreshold - (lowLightThreshold - envHSL.z) * 0.5, 0.0, 100.0);  // Slightly decrease lightness
        }

        const float hueAdjustment = 10.0;  // Adjust hue by 5 degrees (or any small value)
        envHSL.x = fmod(envHSL.x + hueAdjustment, 360.0);  // Ensure the hue wraps around [0, 360]
    }

    // Step 5: Mix the result with baseColor (baseColor has minor contribution)
    float3 adjustedEnvColor = hsl_to_rgb(envHSL);  // Convert adjusted HSL back to RGB

    // Step 6: Return the final mixed color
    return adjustedEnvColor;
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
color2 *= 1.2;

float3 shiftedColor1 = adjust_hsl_to_stand_out_in_environment(color1.rgb, color2.rgb);

//shiftedColor1 = float3(1.0);

if(all(color2.rgb < float3(0.001, 0.001, 0.001))){
    return float4(color1.rgb, 1.0);
}else{
    return float4(shiftedColor1, 1.0);
}
}