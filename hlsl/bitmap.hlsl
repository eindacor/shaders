
#define maxColorDistance 1.73f

uniform float u_Threshold; 
uniform float u_OutputR;
uniform float u_OutputG;
uniform float u_OutputB; 

uniform float u_CompareR;
uniform float u_CompareG;
uniform float u_CompareB;

float normalizeInputVal(float value) {
    return (value + 1000.f) / 2000.f;
}

float getBrightness(float3 color) {
    return (color.r + color.g + color.b) / 3.f;
}

float4 mainImage( VertData v_in ) : TARGET
{
    float4 sampleColor = image.Sample(textureSampler, v_in.uv);
    float4 outputColor = float4(normalizeInputVal(u_OutputR), normalizeInputVal(u_OutputG), normalizeInputVal(u_OutputB), 1.f);
    float4 compareColor = float4(normalizeInputVal(u_CompareR), normalizeInputVal(u_CompareG), normalizeInputVal(u_CompareB), 1.f);

    if (distance(sampleColor.rgb, compareColor.rgb) < normalizeInputVal(u_Threshold) * maxColorDistance) {
        return outputColor;
    } else {
        return float4(0.f, 0.f, 0.f, 0.f); 
    }
}