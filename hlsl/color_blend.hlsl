

// from https://www.shadertoy.com/view/4djSRW
float hash(float2 p)
{
    float val = sin(dot(p, float2(12.9898f, 78.233f))) * 43758.5453f;
    return val - floor(val);
}

float normalizeSin(float value) {
    return (value + 1.f) / 2.f;
}

float4 mainImage( VertData v_in ) : TARGET {
    float2 uv = v_in.uv;

    float r = normalizeSin(sin(elapsed_time));

    float4 outColor = float4(
        .75f + .25 * sin(elapsed_time + uv.x), 
        .5f + .5 * cos(elapsed_time + uv.y), 
        .5f, 
        1.f);

    return image.Sample(textureSampler, v_in.uv) * outColor;
}