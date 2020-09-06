
#define SAMPLE_COUNT 4

uniform float u_SampleSize = 0.1f;

struct AspectRatioMatrices {
    float2x2 scaleMatrix;
    float2x2 inverseScaleMatrix;
};

AspectRatioMatrices getAspectRatioMatrices(float2 uvSize) {
    float aspectRatio = uvSize.x / uvSize.y;
    AspectRatioMatrices aspectRatioMatrices;
    aspectRatioMatrices.scaleMatrix = float2x2(
        aspectRatio, 0.f,
        0.f, 1.f
    );
    
    aspectRatioMatrices.inverseScaleMatrix = float2x2(
        1.f / aspectRatio, 0.f,
        0.f, 1.f
    );

    return aspectRatioMatrices;
}

float4 mainImage( VertData v_in ) : TARGET {
    AspectRatioMatrices aspectRatioMatrices = getAspectRatioMatrices(uv_size);

    float2 adjustedUV = mul(v_in.uv, aspectRatioMatrices.scaleMatrix);

    float sampleSize = pow(u_SampleSize, 2.f);
    float leftEdge = floor(adjustedUV.x / sampleSize) * sampleSize;
    float lowerEdge = floor(adjustedUV.y / sampleSize) * sampleSize;

    float4 outColor = float4(0.f, 0.f, 0.f, 1.f);
    int sampleCount = 0;
    float sampleIncrement = sampleSize / float(SAMPLE_COUNT);
    for (int i=0; i<SAMPLE_COUNT; i++) {
        float xSample = leftEdge + float(i) * sampleIncrement;

        for (int n=0; n<SAMPLE_COUNT; n++) {
            float ySample = lowerEdge + float(n) * sampleIncrement;
            float2 sampleUV = mul(float2(xSample, ySample), aspectRatioMatrices.inverseScaleMatrix);

            if (sampleUV.x < 0.f || sampleUV.x > 1.f || sampleUV.y < 0.f || sampleUV.y > 1.f) {
                continue;
            }

            // TODO test this
            outColor += image.Sample(textureSampler, sampleUV);
            sampleCount++;
        }
    }

    if (sampleCount == 0) {
        return outColor;
    }

    outColor /= float(sampleCount);
    return outColor;
}