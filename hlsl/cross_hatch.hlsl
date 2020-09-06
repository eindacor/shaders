
#define TWOPI 6.28318530718f
#define AA 0.001f
#define SAMPLE_INCREMENTS 4
#define MAX_HATCH_LINES 10
#define SAMPLE_SIZE 0.001f

uniform float u_GlobalHatchRotation = 0.15f;
uniform float u_HatchAngleIncrement = 0.6f;
uniform float u_HatchDistance = 0.17f;
uniform float u_HatchLineThickness = 0.08f;
uniform float u_AdjustBrightness = 0.1f;
uniform float u_HatchLines = 1.f;
uniform float u_LineFuzziness = 0.85f;
uniform float u_LineWaviness = 0.14f;
uniform float u_LineWavelength = 0.03f;

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

// from https://www.shadertoy.com/view/4djSRW
float hash(float2 p)
{
    float val = sin(dot(p, float2(12.9898f, 78.233f))) * 43758.5453f;
    return val - floor(val);
}

float randomSignedValue(float2 p) {
    return hash(p) * 2.f - 1.f;
}

float2x2 createRotationMatrix(float rotation) {
    return float2x2(
        cos(rotation), -sin(rotation),
        sin(rotation), cos(rotation)
    );
}

float getHatchValue(float2 uv, float rotation, AspectRatioMatrices aspectRatioMatrices) {
    float hatchDist = pow(u_HatchDistance, 3.f);

    float2x2 rotationMatrix = createRotationMatrix(rotation);

    float2 adjustedUV = mul(uv, mul(aspectRatioMatrices.scaleMatrix, rotationMatrix));

    float closestLineX = round(adjustedUV.x / hatchDist) * hatchDist;

    float previousYNode = floor(adjustedUV.y / u_LineWavelength) * u_LineWavelength;
    float nextYNode = ceil(adjustedUV.y / u_LineWavelength) * u_LineWavelength;

    // modify nodes by some random, deterministic value
    float lineWaviness = pow(u_LineWaviness, 3.f);
    float2 previousNode = 
        float2(closestLineX + lineWaviness * randomSignedValue(float2(closestLineX, previousYNode)),
            previousYNode);
    float2 nextNode = 
        float2(closestLineX + lineWaviness * randomSignedValue(float2(closestLineX, nextYNode)), 
            nextYNode);

    float segmentAngle = atan((previousNode.y - nextNode.y) / (previousNode.x - nextNode.x));
    float2x2 lineRotationMatrix = createRotationMatrix(segmentAngle);

    // essentially rotate the sample UV around the previous node, 
    // then check to see how close it is to that line
    float2 lineSampleUV = adjustedUV - previousNode;
    lineSampleUV = mul(lineSampleUV, lineRotationMatrix);

    float lineThickness = pow(u_HatchLineThickness, 3.f);
    float halfThickness = lineThickness / 2.f;

    // lineSampleUV should now be in the coordinate space of the hatch line segment
    float maxLineFuzziness = .5f * u_LineFuzziness;
    float topLineFuzz = randomSignedValue(uv) * maxLineFuzziness * lineThickness;
    float bottomLineFuzz = randomSignedValue(adjustedUV) * maxLineFuzziness * lineThickness;

    float upperLineEdge = halfThickness + topLineFuzz;
    float lowerLineEdge = -halfThickness + bottomLineFuzz;

    if (lineSampleUV.y > 0.f) {
        return smoothstep(upperLineEdge + AA, upperLineEdge - AA, lineSampleUV.y);
    } else {
        return smoothstep(lowerLineEdge - AA, lowerLineEdge + AA, lineSampleUV.y);
    }
}

float4 mainImage( VertData v_in ) : TARGET {
    float aspectRatio = uv_size.x / uv_size.y;
    float2 uv = v_in.uv;

    AspectRatioMatrices aspectRatioMatrices = getAspectRatioMatrices(uv_size);

    float2 aspectUV = mul(uv, aspectRatioMatrices.scaleMatrix);

    SampleData sampleData = getSampleData(uv, aspectRatioMatrices, SAMPLE_SIZE);

    float sampleBrightness = getBrightness(sampleData.color.rgb);

    int hatchCount = getHatchCount(getBrightness(sampleData.color.rgb));

    float4 outColor = u_ClearColor;
    float hatchAngleIncrement = u_HatchAngleIncrement * TWOPI;
    for (int i=0; i<hatchCount; i++) {
        float hatchRotation = float(i + 1) * hatchAngleIncrement * u_GlobalHatchRotation;
        float hatchValue = getHatchValue(uv, hatchRotation, aspectRatioMatrices);

        // add some noise to actual stroke of the line so it isn't 100% solid
        // TODO replace with noise maps so it isn't so inconsistent
        float innerFuzziness = 1.f - (hash(uv) * .5f);
        outColor = lerp(outColor, u_LineColor, hatchValue * innerFuzziness);
    }
    
    return outColor;
}