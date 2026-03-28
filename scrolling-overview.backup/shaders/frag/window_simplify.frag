#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

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

vec4 sampleDominantColor(vec2 centerUV, vec2 pixelSize) {
    vec4 samples[5];
    samples[0] = texture(source, centerUV);
    samples[1] = texture(source, centerUV + vec2(-pixelSize.x, -pixelSize.y) * 0.4);
    samples[2] = texture(source, centerUV + vec2( pixelSize.x, -pixelSize.y) * 0.4);
    samples[3] = texture(source, centerUV + vec2(-pixelSize.x,  pixelSize.y) * 0.4);
    samples[4] = texture(source, centerUV + vec2( pixelSize.x,  pixelSize.y) * 0.4);
    
    vec4 dominant = samples[0] * 0.4;
    dominant += samples[1] * 0.15;
    dominant += samples[2] * 0.15;
    dominant += samples[3] * 0.15;
    dominant += samples[4] * 0.15;
    
    return dominant;
}

vec3 posterize(vec3 color, float levels) {
    float steps = max(levels - 1.0, 1.0);
    return floor(color * steps + 0.5) / steps;
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
    
    float pixelsPerHundred = mix(15.0, 25.0, ubuf.pixelDensity);
    float gridDensity = pixelsPerHundred / 100.0;
    
    float minGridSize = 16.0;
    float maxGridSize = 512.0;
    
    vec2 gridSize = texSize * gridDensity;
    gridSize.x = clamp(gridSize.x, minGridSize, maxGridSize);
    gridSize.y = gridSize.x * (texSize.y / texSize.x);
    
    vec2 pixelSize = 1.0 / gridSize;
    
    vec2 pixelatedUV = floor(qt_TexCoord0 * gridSize) / gridSize;
    pixelatedUV += 0.5 / gridSize;
    
    vec4 color = sampleDominantColor(pixelatedUV, pixelSize);
    
    color.rgb = adjustSaturation(color.rgb, ubuf.saturation);
    color.rgb = adjustContrast(color.rgb, ubuf.contrast);
    
    color.rgb = clamp(color.rgb, 0.0, 1.0);
    
    float levels = pow(2.0, ubuf.colorDepth);
    color.rgb = posterize(color.rgb, levels);
    
    color.a = originalColor.a;
    
    fragColor = mix(originalColor, color, ubuf.intensity) * ubuf.qt_Opacity;
}
