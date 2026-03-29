#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

// Must match window_simplify.frag layout for drop-in compatibility
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float intensity;
    float sourceWidth;
    float sourceHeight;
    float pixelDensity;
    float colorDepth;
    float saturation;
    float contrast;
} ubuf;

float ditherThreshold(vec2 fragCoord) {
    vec2 p = mod(fragCoord, 8.0);
    int x = int(p.x);
    int y = int(p.y);
    
    // We cannot use large constant arrays in legacy GLSL profiles (like GLSL ES 100 used by Qt).
    // Instead we use nested switch/if or encode it into 16 vec4s.
    // For 8x8, it's easier to use a 4x4 matrix mathematically and expand it.
    
    // 4x4 Bayer Matrix
    // 0  8  2 10
    // 12  4 14  6
    // 3 11  1  9
    // 15  7 13  5
    int bayer4x4 = 0;
    int bx = int(mod(float(x), 4.0));
    int by = int(mod(float(y), 4.0));
    
    if (by == 0) {
        if (bx == 0) bayer4x4 = 0; else if (bx == 1) bayer4x4 = 8; else if (bx == 2) bayer4x4 = 2; else bayer4x4 = 10;
    } else if (by == 1) {
        if (bx == 0) bayer4x4 = 12; else if (bx == 1) bayer4x4 = 4; else if (bx == 2) bayer4x4 = 14; else bayer4x4 = 6;
    } else if (by == 2) {
        if (bx == 0) bayer4x4 = 3; else if (bx == 1) bayer4x4 = 11; else if (bx == 2) bayer4x4 = 1; else bayer4x4 = 9;
    } else {
        if (bx == 0) bayer4x4 = 15; else if (bx == 1) bayer4x4 = 7; else if (bx == 2) bayer4x4 = 13; else bayer4x4 = 5;
    }
    
    // Expand to 8x8
    int bayer8x8 = bayer4x4 * 4;
    int cx = x / 4;
    int cy = y / 4;
    
    if (cy == 0) {
        if (cx == 0) bayer8x8 += 0; else bayer8x8 += 2;
    } else {
        if (cx == 0) bayer8x8 += 3; else bayer8x8 += 1;
    }
    
    return (float(bayer8x8) + 0.5) / 64.0;
}

vec3 adjustSaturation(vec3 color, float amount) {
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    return mix(vec3(luma), color, amount);
}

vec3 adjustContrast(vec3 color, float amount) {
    return (color - 0.5) * amount + 0.5;
}

void main() {
    vec4 originalColor = texture(source, qt_TexCoord0);
    
    if (ubuf.intensity <= 0.001) {
        fragColor = originalColor * ubuf.qt_Opacity;
        return;
    }
    
    vec2 texSize = vec2(max(ubuf.sourceWidth, 1.0), max(ubuf.sourceHeight, 1.0));
    
    // Pixel scale logic
    float pixelsPerHundred = mix(20.0, 40.0, ubuf.pixelDensity); // slightly higher res for classic mac
    float gridDensity = pixelsPerHundred / 100.0;
    
    float minGridSize = 32.0;
    float maxGridSize = 1024.0;
    
    vec2 gridSize = texSize * gridDensity;
    gridSize.x = clamp(gridSize.x, minGridSize, maxGridSize);
    gridSize.y = gridSize.x * (texSize.y / texSize.x);
    
    // Pixelate UVs
    vec2 pixelatedUV = floor(qt_TexCoord0 * gridSize) / gridSize;
    pixelatedUV += 0.5 / gridSize; // center tap
    
    vec4 color = texture(source, pixelatedUV);
    
    // Color space adjustments
    // If we want raw Mac OS 1-bit, reducing saturation before quantizing creates strong black&white edges
    color.rgb = adjustSaturation(color.rgb, ubuf.saturation);
    color.rgb = adjustContrast(color.rgb, ubuf.contrast);
    color.rgb = clamp(color.rgb, 0.0, 1.0);
    
    // Determine screen position of the virtual macro-pixel 
    vec2 fragCoord = pixelatedUV * gridSize;
    
    // Get Bayer threshold for this alternating pixel
    float threshold = ditherThreshold(fragCoord);
    
    // We add threshold noise to the color value and then cleanly posterize.
    // The standard equation is mapping normalized color into [0, levels-1], adding threshold, and flooring.
    float levels = pow(2.0, ubuf.colorDepth);
    float steps = max(levels - 1.0, 1.0);

    // Apply Bayer Dither
    // Normal posterize is floor(color * steps + 0.5) / steps.
    // With dither, we replace the "+ 0.5" rounder with our varying threshold matrix.    
    color.r = floor(color.r * steps + threshold) / steps;
    color.g = floor(color.g * steps + threshold) / steps;
    color.b = floor(color.b * steps + threshold) / steps;

    color.a = originalColor.a;
    
    fragColor = mix(originalColor, color, ubuf.intensity) * ubuf.qt_Opacity;
}
