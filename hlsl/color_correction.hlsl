
uniform float4 u_Color = { 1.f, 1.f, 1.f, 1.f };

float4 mainImage( VertData v_in ) : TARGET
{
    float4 texColor = image.Sample(textureSampler, v_in.uv);
    float r = u_Color.r * texColor.r;
    float g = u_Color.g * texColor.g;
    float b = u_Color.b * texColor.b;
    return float4(r, g, b, texColor.a);
}