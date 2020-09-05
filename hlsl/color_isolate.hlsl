uniform float4 u_Color0 = { 0.f, 0.f, 0.f, 1.0};
uniform float u_MatchThreshold_0 = 0.f;

uniform float4 u_Color1 = { 0.f, 0.f, 0.f, 1.0};
uniform float u_MatchThreshold_1 = 0.f;

uniform float4 u_Color2 = { 0.f, 0.f, 0.f, 1.0};
uniform float u_MatchThreshold_2 = 0.f;

float getBrightness(float3 color) {
    return (color.r + color.g + color.b) / 3.f;
}

#define maxColorDistance 1.73f

float4 mainImage( VertData v_in ) : TARGET
{    
    float threshold0 = u_MatchThreshold_0 * maxColorDistance;
    float threshold1 = u_MatchThreshold_1 * maxColorDistance;
    float threshold2 = u_MatchThreshold_2 * maxColorDistance;

    float4 sampleColor = image.Sample(textureSampler, v_in.uv);

    if (distance(sampleColor.rgb, u_Color0.rgb) < threshold0 || 
        distance(sampleColor.rgb, u_Color1.rgb) < threshold1 || 
        distance(sampleColor.rgb, u_Color2.rgb) < threshold2) {
        return sampleColor;
    } else {
        float brightness = getBrightness(sampleColor.rgb);
        return float4(brightness, brightness, brightness, 1.f);
    }
}