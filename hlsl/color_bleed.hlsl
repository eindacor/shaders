uniform float u_RChannel;
uniform float u_GChannel;
uniform float u_BChannel; 

#define searchDistance 24

float4 mainImage( VertData v_in ) : TARGET
{
    float pixelHeight = 1.f / uv_size.y;
    float3 targetColor = float3(u_RChannel, u_GChannel, u_BChannel);

    for (int i=0; i<searchDistance; i++) {
        float yOffset = pixelHeight * float(searchDistance) - float(i) * pixelHeight;
        float2 uv = float2(v_in.uv.x, v_in.uv.y - yOffset);
        if (uv.y > 1.f || uv.y < 0.f) {
            continue;
        }
        // look until you find a pixel close enough to color
        float4 sampleColor = image.Sample(textureSampler, uv);

        if (distance(sampleColor.rgb, targetColor) < .5f) {
            return sampleColor;
            //return float4(0.f, 0.f, 0.f, 1.f);
        }

    }

    return image.Sample(textureSampler, v_in.uv);
}