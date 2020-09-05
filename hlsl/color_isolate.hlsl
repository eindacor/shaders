uniform float u_RChannel_0;
uniform float u_GChannel_0;
uniform float u_BChannel_0; 
uniform float u_MatchThreshold_0;

uniform float u_RChannel_1;
uniform float u_GChannel_1;
uniform float u_BChannel_1; 
uniform float u_MatchThreshold_1;

uniform float u_RChannel_2;
uniform float u_GChannel_2;
uniform float u_BChannel_2; 
uniform float u_MatchThreshold_2;

float normalizeInputVal(float value) {
    return (value + 1000.f) / 2000.f;
}

float getBrightness(float3 color) {
    return (color.r + color.g + color.b) / 3.f;
}

#define maxColorDistance 1.73f

float4 mainImage( VertData v_in ) : TARGET
{
    float3 targetColor0 = float3(normalizeInputVal(u_RChannel_0), normalizeInputVal(u_GChannel_0), normalizeInputVal(u_BChannel_0));
    float3 targetColor1 = float3(normalizeInputVal(u_RChannel_1), normalizeInputVal(u_GChannel_1), normalizeInputVal(u_BChannel_1));
    float3 targetColor2 = float3(normalizeInputVal(u_RChannel_2), normalizeInputVal(u_GChannel_2), normalizeInputVal(u_BChannel_2));
    
    float threshold0 = normalizeInputVal(u_MatchThreshold_0) * maxColorDistance;
    float threshold1 = normalizeInputVal(u_MatchThreshold_1) * maxColorDistance;
    float threshold2 = normalizeInputVal(u_MatchThreshold_2) * maxColorDistance;

    float4 sampleColor = image.Sample(textureSampler, v_in.uv);

    if (distance(sampleColor.rgb, targetColor0) < threshold0 || distance(sampleColor.rgb, targetColor1) < threshold1 || distance(sampleColor.rgb, targetColor2) < threshold2) {
        return sampleColor;
    } else {
        float brightness = getBrightness(sampleColor.rgb);
        return float4(brightness, brightness, brightness, 1.f);
    }
}