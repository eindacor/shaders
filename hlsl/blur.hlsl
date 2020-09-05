
#define radialSampleLevel 16
#define radialSampleDistance 6

#define orthoSampleLevel 4
#define orthoSampleDistance 6
#define TWOPI 6.28318530718f

#define useRadial false

bool isValidUV(float2 uv) {
    return uv.x >= 0.f && uv.x <= 1.f &&
        uv.y >= 0.f && uv.y <= 1.f;
}

float2 rotatePointAroundOtherPoint(float2 center, float2 p, float angleInRadians) {
    float2x2 rotationMatrix = float2x2 (
        cos(angleInRadians), -sin(angleInRadians),
        sin(angleInRadians), cos(angleInRadians)
    );
    
    return (mul((p - center), rotationMatrix)) + center;
}

float4 orthoBlur(float2 uv, float2 screenResolution) {
    float4 outColor = float4(0.f, 0.f, 0.f, 1.f);

    // n layers above and below, plus the row/column of the current uv
    int totalRowsColumns = orthoSampleLevel * 2 + 1;
    int sampleCount = 0;
    int2 uvIndices = int2(int(uv.x * screenResolution.x), int(uv.y * screenResolution.y));
    int offset = orthoSampleDistance - orthoSampleLevel;

    for (int row=0; row<totalRowsColumns; row++) {
        int actualRow = uvIndices.y + row * offset;
        for (int column=0; column<totalRowsColumns; column++) {
            int actualColumn = uvIndices.x + column * offset;
            float2 sampleUV = float2(float(actualColumn) / screenResolution.x, float(actualRow) / screenResolution.y);

            if (!isValidUV(sampleUV)) {
                continue;
            }

            // sample from actual location
            float4 sampleColor = image.Sample(textureSampler, sampleUV);
            outColor += sampleColor;
            ++sampleCount;
        }
    }

    outColor /= float(sampleCount);
    outColor.a = 1.f;

    return outColor;
}

float4 radialBlur(float2 uv, float2 screenResolution) {
    float4 outColor = image.Sample(textureSampler, uv);

    int sampleCount = 1;
    int2 uvIndices = int2(int(uv.x * screenResolution.x), int(uv.y * screenResolution.y));

    float pixelDist = 1.f / screenResolution.y;
    float2 offset = float2(0.f, float(radialSampleDistance) * pixelDist);

    for (int i=0; i<radialSampleLevel; i++) {
        float rotationAngle = float(i) * TWOPI / float(radialSampleLevel);
        float2 rotated = rotatePointAroundOtherPoint(uv, uv + offset, rotationAngle);
        if (!isValidUV(rotated)) {
                continue;
            }
        
        outColor += image.Sample(textureSampler, rotated);
        ++sampleCount;
    }

    outColor /= float(sampleCount);
    outColor.a = 1.f;

    return outColor;
}

float4 mainImage( VertData v_in ) : TARGET
{
    return  useRadial ? radialBlur(v_in.uv, uv_size) : orthoBlur(v_in.uv, uv_size);
}