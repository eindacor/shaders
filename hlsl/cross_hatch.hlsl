
#define TWOPI 6.28318530718f
#define AA .0001f
#define SAMPLE_INCREMENTS 4
#define MAX_HATCH_LINES 6

uniform float u_GlobalHatchRotation = 0.15f;
uniform float u_SampleDistance = 0.1f;
uniform float u_HatchAngleIncrement = 0.6f;
uniform float u_HatchDistance = 0.2f;
uniform float u_HatchLineThickness = 0.03f;
uniform float u_AdjustBrightness = 0.1f;
uniform float u_HatchLines = .75f;

uniform float4 u_ClearColor = { 1.f, 1.f, 1.f, 1.f };
uniform float4 u_LineColor = { 0.f, 0.f, 0.f, 1.f};

int getHatchCount(float brightness) {
    float hatchSampleIncrement = 1.f / max(1.f, u_HatchLines * float(MAX_HATCH_LINES));
    return int((1.f - brightness * u_AdjustBrightness) / hatchSampleIncrement);
}

float getBrightness(float3 color) {
    return (color.r + color.g + color.b) / 3.f;
}

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

struct SampleData {
    float4 color;
};

SampleData getSampleData(float2 uv, AspectRatioMatrices aspectRatioMatrices, float sampleSize) {  
    float2 aspectUV = mul(uv, aspectRatioMatrices.scaleMatrix);
    float leftEdge = floor(aspectUV.x / sampleSize) * sampleSize;
    float rightEdge = leftEdge + sampleSize;
    float bottomEdge = floor(aspectUV.y / sampleSize) * sampleSize;
    float topEdge = bottomEdge + sampleSize;

    float xIncrement = (rightEdge - leftEdge) / float(SAMPLE_INCREMENTS);
    float yIncrement = (topEdge - bottomEdge) / float(SAMPLE_INCREMENTS);
    
    int sampleCount = 0;
    
    float4 outColor = float4(0.f, 0.f, 0.f, 1.f);
    for (int i=0; i<SAMPLE_INCREMENTS; i++) {
        float x = leftEdge + float(i) * xIncrement;     
        for (int n=0; n<SAMPLE_INCREMENTS; n++) {
            float2 sampleUV = float2(x, bottomEdge + float(n) * yIncrement);
            float2 unadjustedSampleUV = mul(sampleUV, aspectRatioMatrices.inverseScaleMatrix);
            
            // ignore if un-aspected uv would fall outside the image bounds
            if (unadjustedSampleUV.x < 0.f || unadjustedSampleUV.x > 1.f ||
               unadjustedSampleUV.y < 0.f || unadjustedSampleUV.y > 1.f) {
                continue;   
            }
        
            float4 sampleColor = image.Sample(textureSampler, unadjustedSampleUV);
            outColor += sampleColor;
            sampleCount++;
        }
    }

    SampleData sampleData;
    sampleData.color = outColor;
    return sampleData;
}

float getHatchValue(float2 uv, float rotation, AspectRatioMatrices aspectRatioMatrices) {
    float2x2 rotationMatrix = float2x2(
        cos(rotation), -sin(rotation),
        sin(rotation), cos(rotation)
    );

    float adjustedUV = mul(uv, mul(aspectRatioMatrices.scaleMatrix, rotationMatrix));
    float hatchDist = pow(u_HatchDistance, 3.f);

    float closestLineX = round(adjustedUV.x / hatchDist) * hatchDist;

    float lineThickness = pow(u_HatchLineThickness, 2.f);
    float leftLineEdge = closestLineX - lineThickness / 2.f;
    float rightLineEdge = closestLineX + lineThickness / 2.f;

    if (closestLineX > adjustedUV.x) {
        return smoothstep(leftLineEdge - AA, leftLineEdge + AA, adjustedUV.x);
    } else {
        return smoothstep(rightLineEdge + AA, rightLineEdge - AA, adjustedUV.x);
    }
}

float4 mainImage( VertData v_in ) : TARGET {
    float aspectRatio = uv_size.x / uv_size.y;
    float2 uv = v_in.uv;

    AspectRatioMatrices aspectRatioMatrices = getAspectRatioMatrices(uv_size);

    float2 aspectUV = mul(uv, aspectRatioMatrices.scaleMatrix);

    float sampleSize = pow(u_SampleDistance, 3.f);
    SampleData sampleData = getSampleData(uv, aspectRatioMatrices, sampleSize);

    int hatchCount = getHatchCount(getBrightness(sampleData.color.rgb));

    float4 outColor = u_ClearColor;
    float hatchAngleIncrement = u_HatchAngleIncrement * TWOPI;
    for (int i=0; i<hatchCount; i++) {
        float hatchRotation = float(i + 1) * hatchAngleIncrement * u_GlobalHatchRotation;
        float hatchValue = getHatchValue(uv, hatchRotation, aspectRatioMatrices);
        outColor = lerp(outColor, u_LineColor, hatchValue);
    }
    
    return outColor;
}