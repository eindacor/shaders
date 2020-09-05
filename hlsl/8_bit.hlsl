
float4 mainImage( VertData v_in ) : TARGET
{
    float4 sampleColor = image.Sample(textureSampler, v_in.uv);
    return float4(floor(sampleColor.r * 8.f) / 8.f, floor(sampleColor.g * 8.f) / 8.f, floor(sampleColor.b * 4.f) / 4.f, 1.f);
}