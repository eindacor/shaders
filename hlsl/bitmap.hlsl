
#define maxColorDistance 1.73f

uniform float u_Threshold = 0.5f; 
uniform float4 u_OutputColor = { 1.f, 1.f, 1.f, 1.0f };
uniform float4 u_CompareColor = { 1.f, 1.f, 1.f, 1.0f };
uniform float4 u_ClearColor = { 0.f, 0.f, 0.f, 1.0f };

float getBrightness(float3 color) {
    return (color.r + color.g + color.b) / 3.f;
}

float4 mainImage( VertData v_in ) : TARGET
{
    float4 sampleColor = image.Sample(textureSampler, v_in.uv);

    if (distance(sampleColor.rgb, u_CompareColor.rgb) < u_Threshold * maxColorDistance) {
        return u_OutputColor;
    } else {
        return u_ClearColor; 
    }
}