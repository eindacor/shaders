uniform float u_RChannel;
uniform float u_GChannel;
uniform float u_BChannel; 

float normalizeInputVal(float value) {
    return (value + 1000.f) / 2000.f;
}

float4 mainImage( VertData v_in ) : TARGET
{
    float4 texColor = image.Sample(textureSampler, v_in.uv);
    float r = normalizeInputVal(u_RChannel) * texColor.r;
    float g = normalizeInputVal(u_GChannel) * texColor.g;
    float b = normalizeInputVal(u_BChannel) * texColor.b;
    return float4(r, g, b, texColor.a);
}