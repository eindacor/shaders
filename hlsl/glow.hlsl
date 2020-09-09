
uniform float u_BrightnessThreshold;
uniform float u_SearchDist;

#define maxSearchDist 0.2f
#define searchIncrements 4
#define searchSamples 10
#define TWOPI 6.28318530718f

// normalizes the default slider inputs from OBS Shader plugin thingy (-1000 to 1000)
float normalizeInputVal(float value) {
    return (value + 1000.f) / 2000.f;
}

float2 rotatePointAroundOtherPoint(float2 center, float2 p, float angleInRadians) {
    float2x2 rotationMatrix = float2x2 (
        cos(angleInRadians), -sin(angleInRadians),
        sin(angleInRadians), cos(angleInRadians)
    );
    
    return (mul((p - center), rotationMatrix)) + center;
}

float getBrightness(float3 color) {
    return (color.r * 0.2126f + color.g * 0.7152f + color.b * 0.0722f);
}

bool testBounds(float2 uv) {
    return uv.x > 0.f && uv.x < 1.f && uv.y > 0.f && uv.y < 1.f;
}

float4 mainImage( VertData v_in ) : TARGET{
    // look for bright colors nearby based on u_BrightnessThreshold, borrow from that color based on distance

    float4 texColor = image.Sample(textureSampler, v_in.uv);
    texColor.a = 1.f;
    float searchDistance = maxSearchDist * normalizeInputVal(u_SearchDist);
    float brightnessThreshold = normalizeInputVal(u_BrightnessThreshold);

    if (getBrightness(texColor.rgb) > brightnessThreshold) {
        return texColor;
    }

    for (int i=0; i<searchSamples; i++) {
        // determine sample rotation
        float rotationAngle = float(i) * TWOPI / float(searchSamples);
        float4 maxBrightessThisAngle = float4(0.f, 0.f, 0.f, 1.f);
        float sampleDistanceThisAngle = 0.f;
        bool sampleFound = false;

        for (int n=0; n<searchIncrements; n++) {
            float sampleDistance = float(n) * searchDistance / float(searchIncrements);
            float2 sampleUV = v_in.uv + float2(0.f, sampleDistance);
            sampleUV = rotatePointAroundOtherPoint(v_in.uv, sampleUV, rotationAngle);

            if (!testBounds(sampleUV)) {
                continue;
            }

            float4 sampleColor = image.Sample(textureSampler, sampleUV);

            float sampleBrightness = getBrightness(sampleColor.rgb);
            if (sampleBrightness > brightnessThreshold && sampleBrightness > getBrightness(maxBrightessThisAngle.rgb)) {
                maxBrightessThisAngle = sampleColor;
                sampleDistanceThisAngle = sampleDistance;
                sampleFound = true;
            }
        }

        if (sampleFound) {
            // TODO test making texColor dimmer based on brightness
            // adjust texColor based on distance
            float colorAdjustment = pow(1.f - sampleDistanceThisAngle, 20.f);
            texColor = lerp(texColor, maxBrightessThisAngle, colorAdjustment);

            if (getBrightness(texColor.rgb) > brightnessThreshold) {
                return texColor;
            }
        }
    }

    return texColor;
    // float4 reduced = texColor * .8f;
    // reduced.a = texColor.a;
    // return reduced;
}