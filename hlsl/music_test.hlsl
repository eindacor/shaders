float4 mainImage( VertData v_in ) : TARGET
{
    float4 texColor = image.Sample(textureSampler, v_in.uv);
    float alpha = (texColor.r + texColor.g + texColor.b) < .01f ? 0.f : 1.f;
    return float4(texColor.rgb, alpha);
}