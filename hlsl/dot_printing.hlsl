

#define CYAN float4(0.f, 1.f, 1.f, 1.f)
#define MAGENTA float4(1.f, 0.f, 1.f, 1.f)
#define YELLOW float4(1.f, 1.f, 0.f, 1.f)
#define BLACK float4(0.f, 0.f, 0.f, 1.f)
#define RED float4(1.f, 0.f, 0.f, 1.f)
#define GREEN float4(0.f, 1.f, 0.f, 1.f)
#define BLUE float4(0.f, 0.f, 1.f, 1.f)

#define WHITE float4(1.f, 1.f, 1.f, 1.f)

#define MAX_SAMPLE_SIZE .1f

#define SAMPLE_INCREMENTS 4
#define TWOPI 6.28318530718f

#define COLOR_MATCH_BLACK true
#define COLOR_MATCH_COLOR true

#define AA .001f
#define ALMOST_ZERO .00001f

uniform float u_SampleSize = 0.09f;
uniform float u_DotCoverage = 1.f;

uniform float u_RotationC = 0.1f;
uniform float u_RotationM = 0.3f;
uniform float u_RotationY = 0.5f;
uniform float u_RotationK = 0.7f;

uniform float u_ColorMatchThresholdC = 0.f;
uniform float u_ColorMatchThresholdM = 0.f;
uniform float u_ColorMatchThresholdY = 0.f;
uniform float u_ColorMatchThresholdK = 0.18f;
uniform float u_ColorMatchThresholdR = 0.f;
uniform float u_ColorMatchThresholdG = 0.f;
uniform float u_ColorMatchThresholdB = 0.f;

uniform float4 u_ClearColor = { 1.f, 0.98f, 0.95f, 1.f };

// https://www.rapidtables.com/convert/color/rgb-to-cmyk.html
float getBlackValue(float4 color) {
    return 1.f - max(color.r, max(color.g, color.b));
}

float getCyanValue(float4 color) {
    float blackValue = getBlackValue(color);
    return (1.f - color.r -blackValue) / (1.f - blackValue);
}

float getMagentaValue(float4 color) {
    float blackValue = getBlackValue(color);
    return (1.f - color.g - blackValue) / (1.f - blackValue);
}

float getYellowValue(float4 color) {
    float blackValue = getBlackValue(color);
    return (1.f - color.b - blackValue) / (1.f - blackValue);    
}

struct sampleData {
    bool withinMax;
    float distFromCenter;
    float4 sampleColor;
};

sampleData getSampleColor(float rotation, 
            float2x2 scaleMatrix, 
            float2x2 inverseScaleMatrix, 
            float2 uv, 
            float maxDist,
            float gridSize) 
{
    sampleData returnData;

    float2x2 rotationMatrix = float2x2(
        cos(rotation), -sin(rotation),
        sin(rotation), cos(rotation)
    );
    
    float2x2 inverseRotationMatrix = float2x2(
        cos(-rotation), -sin(-rotation),
        sin(-rotation), cos(-rotation)
    );
    
    float2x2 uvToRotated = mul(scaleMatrix, rotationMatrix);
    float2x2 rotatedToUV = mul(inverseRotationMatrix, inverseScaleMatrix);
    
    float2 rotatedUV = mul(uv, uvToRotated);
                
    float leftEdge = floor(rotatedUV.x / gridSize) * gridSize;
    float rightEdge = leftEdge + gridSize;
    float bottomEdge = floor(rotatedUV.y / gridSize) * gridSize;
    float topEdge = bottomEdge + gridSize;
    
    float2 areaCenter = float2(leftEdge + (gridSize / 2.f), bottomEdge + (gridSize / 2.f));    
    float distFromCenter = distance(rotatedUV, areaCenter);
    returnData.distFromCenter = distFromCenter;
    if (distFromCenter > maxDist + AA) {
        returnData.withinMax = false;
        return returnData;
    }
    
    float xIncrement = (rightEdge - leftEdge) / float(SAMPLE_INCREMENTS);
    float yIncrement = (topEdge - bottomEdge) / float(SAMPLE_INCREMENTS);
    
    int sampleCount = 0;
    
    float4 outColor = float4(0.f, 0.f, 0.f, 1.f);
    for (int i=0; i<SAMPLE_INCREMENTS; i++) {
        float x = leftEdge + float(i) * xIncrement;     
        for (int n=0; n<SAMPLE_INCREMENTS; n++) {
            float2 sampleUV = float2(x, bottomEdge + float(n) * yIncrement);
            float2 unrotatedSampleUV = mul(sampleUV, rotatedToUV);
            
            if (unrotatedSampleUV.x < 0.f || unrotatedSampleUV.x > 1.f ||
               unrotatedSampleUV.y < 0.f || unrotatedSampleUV.y > 1.f) {
                continue;   
            }
        
            float4 sampleColor = image.Sample(textureSampler, unrotatedSampleUV);
            outColor += sampleColor;
            sampleCount++;
        }
    }

    if (sampleCount == 0) {
        returnData.withinMax = false;
        return returnData;
    }
    
    outColor /= float(sampleCount);

    returnData.sampleColor = float4(outColor.r, outColor.g, outColor.b, 1.f);
    returnData.withinMax = true;

    return returnData;
}

float4 mainImage( VertData v_in ) : TARGET {
    float4 texColor = image.Sample(textureSampler, v_in.uv);

    if (COLOR_MATCH_BLACK && distance(texColor.rgb, BLACK.rgb) < u_ColorMatchThresholdK) {
        return BLACK;
    }

    if (COLOR_MATCH_COLOR) {
        if (distance(texColor.rgb, CYAN.rgb) < u_ColorMatchThresholdC) {
            return CYAN;
        }

        if (distance(texColor.rgb, MAGENTA.rgb) < u_ColorMatchThresholdM) {
            return MAGENTA;
        }

        if (distance(texColor.rgb, YELLOW.rgb) < u_ColorMatchThresholdY) {
            return YELLOW;
        }

        if (distance(texColor.rgb, RED.rgb) < u_ColorMatchThresholdR) {
            return RED;
        }

        if (distance(texColor.rgb, GREEN.rgb) < u_ColorMatchThresholdG) {
            return GREEN;
        }

        if (distance(texColor.rgb, BLUE.rgb) < u_ColorMatchThresholdB) {
            return BLUE;
        }
    }

    float aspectRatio = uv_size.x / uv_size.y;
        
    float2x2 scaleMatrix = float2x2(
        aspectRatio, 0.f,
        0.f, 1.f
    );
    
    float2x2 inverseScaleMatrix = float2x2(
        1.f / aspectRatio, 0.f,
        0.f, 1.f
    );

    float gridSize = max(pow(u_SampleSize, 2.f), .00001f);
    float maxDist = u_DotCoverage * gridSize / 2.f;

    sampleData blackSampleData = getSampleColor(
            u_RotationK * TWOPI, 
            scaleMatrix, 
            inverseScaleMatrix, 
            v_in.uv, 
            maxDist,
            gridSize);


    float blackDrawValue = 0.f;
    if (blackSampleData.withinMax) {
        float blackValue = getBlackValue(blackSampleData.sampleColor);
        float blackDist = maxDist * blackValue;
        blackDrawValue = 1.f - smoothstep(blackDist - AA, blackDist + AA, blackSampleData.distFromCenter); // AA
    }

    sampleData cyanSampleData = getSampleColor(
            u_RotationC * TWOPI, 
            scaleMatrix, 
            inverseScaleMatrix, 
            v_in.uv, 
            maxDist,
            gridSize);


    float cyanDrawValue = 0.f;
    if (cyanSampleData.withinMax) {
        float cyanValue = getCyanValue(cyanSampleData.sampleColor);
        float cyanDist = maxDist * cyanValue;
        cyanDrawValue = 1.f - smoothstep(cyanDist - AA, cyanDist + AA, cyanSampleData.distFromCenter); // AA
    }

    sampleData magentaSampleData = getSampleColor(
            u_RotationM * TWOPI, 
            scaleMatrix, 
            inverseScaleMatrix, 
            v_in.uv, 
            maxDist,
            gridSize);


    float magentaDrawValue = 0.f;
    if (magentaSampleData.withinMax) {
        float magentaValue = getMagentaValue(magentaSampleData.sampleColor);
        float magentaDist = maxDist * magentaValue;
        magentaDrawValue = 1.f - smoothstep(magentaDist - AA, magentaDist + AA, magentaSampleData.distFromCenter); // AA
    }

    sampleData yellowSampleData = getSampleColor(
            u_RotationY * TWOPI, 
            scaleMatrix, 
            inverseScaleMatrix, 
            v_in.uv, 
            maxDist,
            gridSize);


    float yellowDrawValue = 0.f;
    if (yellowSampleData.withinMax) {
        float yellowValue = getYellowValue(yellowSampleData.sampleColor);
        float yellowDist = maxDist * yellowValue;
        yellowDrawValue = 1.f - smoothstep(yellowDist - AA, yellowDist + AA, yellowSampleData.distFromCenter); // AA
    }

    // multiply colors for subtractive color mixing
    return 
        lerp(u_ClearColor, BLACK, blackDrawValue) * 
        lerp(u_ClearColor, CYAN, cyanDrawValue) * 
        lerp(u_ClearColor, YELLOW, yellowDrawValue) * 
        lerp(u_ClearColor, MAGENTA, magentaDrawValue);
}


