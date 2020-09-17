

#define MAIN_TRIANGLE_HEIGHT .5f
#define TWOPI 6.28318530718f
#define AA 0.001f
#define SIXTY_DEGREES 1.0471975512f

uniform float u_TimeScaleModifier = .1f;
uniform float u_HexRadius = .8f;
uniform float u_HexBorderThickness = 0.f;
uniform float u_HexTriangleThickness = 0.f;
uniform float u_HexCenterRadius = 0.f;
uniform int u_KaleidoscopeLevels = 2;
uniform float4 u_BorderColor = {1.f, 1.f, 1.f, 1.f};
uniform float4 u_TriangleColor = {1.f, 1.f, 1.f, 1.f};
uniform float4 u_HexCenterColor = {1.f, 1.f, 1.f, 1.f};

// from https://www.shadertoy.com/view/4djSRW
float hash(float2 p)
{
    float val = sin(dot(p, float2(12.9898f, 78.233f))) * 43758.5453f;
    return val - floor(val);
}

struct AspectRatioData {
    float2x2 scaleMatrix;
    float2x2 inverseScaleMatrix;
    float aspectRatio;
};

AspectRatioData getAspectRatioData(float2 uvSize) {
    float aspectRatio = uvSize.x / uvSize.y;
    AspectRatioData aspectRatioData;
    aspectRatioData.aspectRatio = aspectRatio;
    aspectRatioData.scaleMatrix = float2x2(
        aspectRatio, 0.f,
        0.f, 1.f
    );
    
    aspectRatioData.inverseScaleMatrix = float2x2(
        1.f / aspectRatio, 0.f,
        0.f, 1.f
    );

    return aspectRatioData;
}

bool isHexCenter(float2 pos, float hexXIncrement, float hexYIncrement) {
    float columnIndex = round(pos.x / hexXIncrement);
    float rowIndex = round(pos.y / hexYIncrement);
    return int(round(fmod(abs(columnIndex), 2.f))) == int(round(fmod(abs(rowIndex), 2.f)));
}

float getOffsetAngle(float2 first, float2 second) {
    float2 offsetVec = second - first;
    float angle = atan(offsetVec.y / offsetVec.x);
    
    if (first.x > second.x) {
        angle = TWOPI / 2.f + angle;
    } else if (first.y > second.y) {
        angle = TWOPI + angle;
    }
    
    return angle;
}

float2x2 createRotationMatrix(float rotation) {
    return float2x2(
        cos(rotation), -sin(rotation),
        sin(rotation), cos(rotation)
    );
}

float3 float2ToFloat3(float2 vec) {
    return float3(vec.x, vec.y, 0.f);
}

struct KaleidSampleData {
    float4 color;
    float2 uv;
};

float2 getHexCenter(float2 aspectUV, 
                    float2 leftBottom, 
                    float2 leftTop, 
                    float2 rightBottom, 
                    float2 rightTop,
                    float aspectHexGridXIncrement, 
                    float hexGridYIncrement,
                    float aspectHexRadius) {
    float2 hexCenter = float2(-1.f, -1.f); 

    // // if uv is close to hexCenter -> hexDiagRight || hexDiagLeft, return border color
    if (isHexCenter(leftBottom, aspectHexGridXIncrement, hexGridYIncrement)) {
        float2 hexDiagRight = leftBottom + float2(aspectHexRadius, 0.f);
        float2 hexDiagLeft = leftTop + float2(aspectHexRadius / 2.f, 0.f);
        float2 sharedEdgeVector = normalize(float2(hexDiagLeft - hexDiagRight));
        float2 sharedToRightTopVector = normalize(float2(rightTop - hexDiagRight));
        float2 sharedToUVVector = normalize(float2(aspectUV - hexDiagRight));

        float3 crossRightTop = cross(float2ToFloat3(sharedEdgeVector), 
                                    float2ToFloat3(sharedToRightTopVector));
        float3 crossUV = cross(float2ToFloat3(sharedEdgeVector), 
                                float2ToFloat3(sharedToUVVector));

        hexCenter = (crossRightTop.z == crossUV.z) || 
            (crossRightTop.z < 0.f && crossUV.z < 0.f) || 
            (crossRightTop.z > 0.f && crossUV.z > 0.f) ? rightTop : leftBottom;
    } else {
        float2 hexDiagRight = leftTop + float2(aspectHexRadius, 0.f);
        float2 hexDiagLeft = rightBottom - float2(aspectHexRadius, 0.f);
        float2 sharedEdgeVector = normalize(float2(hexDiagRight - hexDiagLeft));
        float2 sharedToRightBottomVector = normalize(float2(rightBottom - hexDiagLeft));
        float2 sharedToUVVector = normalize(float2(aspectUV - hexDiagLeft));

        float3 crossRightBottom = cross(float2ToFloat3(sharedEdgeVector), 
                                        float2ToFloat3(sharedToRightBottomVector));
        float3 crossUV = cross(float2ToFloat3(sharedEdgeVector), 
                                float2ToFloat3(sharedToUVVector));

        hexCenter = crossRightBottom.z == crossUV.z || 
            (crossRightBottom.z < 0.f && crossUV.z < 0.f) || 
            (crossRightBottom.z > 0.f && crossUV.z > 0.f) ? rightBottom : leftTop;
    }

    return hexCenter;
}

KaleidSampleData getKaleidoscopedUV(float2 uv, 
                        AspectRatioData aspectRatioData, 
                        float hexRadius, 
                        float shortRadius, 
                        float angle,
                        float hexGridXIncrement,
                        float hexGridYIncrement) 
{
    float2 aspectUV = mul(uv, aspectRatioData.scaleMatrix);

    float aspectHexGridXIncrement = hexGridXIncrement;

    float leftEdge = floor(aspectUV.x / aspectHexGridXIncrement) * aspectHexGridXIncrement;
    float rightEdge = leftEdge + aspectHexGridXIncrement;
    float bottomEdge = floor(aspectUV.y / hexGridYIncrement) * hexGridYIncrement;
    float topEdge = bottomEdge + hexGridYIncrement;

    KaleidSampleData kaleidSampleData;
    kaleidSampleData.color = float4(0.f, 0.f, 0.f, 0.f);
    kaleidSampleData.uv = float2(0.f, 0.f);
    
    float2 leftBottom = float2(leftEdge, bottomEdge);
    float2 leftTop = float2(leftEdge, topEdge);
    float2 rightTop = float2(rightEdge, topEdge);
    float2 rightBottom = float2(rightEdge, bottomEdge);

    float aspectHexRadius = hexRadius;
    float2 hexCenter = getHexCenter(aspectUV,
                            leftBottom, 
                            leftTop, 
                            rightBottom, 
                            rightTop, 
                            aspectHexGridXIncrement, 
                            hexGridYIncrement,
                            aspectHexRadius);

    float offsetAngle = getOffsetAngle(hexCenter, aspectUV);
    // mulitplying by 5 rotates the uv so the default orientation (0 radians) is facing downward
    offsetAngle = fmod(offsetAngle + 5.f * angle, TWOPI);
    
    int offsetIndex = int(round(floor(offsetAngle / angle)));

    float rotation = float(offsetIndex) * angle;
    
    float2x2 rotationMatrix = createRotationMatrix(rotation);

    float2 kaleidUV = mul((aspectUV - hexCenter), rotationMatrix);
    // kaleidUV is below 0,0 (upper left) with the perfect triangle inverted below 
    // (y flipped in hlsl)

    float aspectRatio = aspectRatioData.aspectRatio;
    float sampleY = kaleidUV.y / shortRadius;
    // this identifies where it is in the triangle, not the image
    float triangleXCoord = (kaleidUV.x + hexRadius / 2.f) / hexRadius; 

    float imageWidthAtScale = shortRadius * aspectRatio;
    float imageTriangleDelta = imageWidthAtScale - hexRadius;
    float sampleX = (imageTriangleDelta / 2.f + triangleXCoord * hexRadius) / imageWidthAtScale;

    if (fmod(offsetIndex, 2) == 1) {
        sampleX = 1.f - sampleX;
    }

    kaleidSampleData.uv = float2(clamp(sampleX, 0.f, 1.f), clamp(sampleY, 0.f, 1.f));

    if (u_HexTriangleThickness > .0001f) {
        float triangleTestRotationMatrix = createRotationMatrix(SIXTY_DEGREES / 2.f);
        float thicknessCheck = u_HexTriangleThickness * .25f;

        float2 relocatedUV = mul(kaleidUV, createRotationMatrix(SIXTY_DEGREES / 2.f));
        float colorVal = smoothstep(thicknessCheck + AA, thicknessCheck - AA, abs(relocatedUV.x));
        kaleidSampleData.color = lerp(kaleidSampleData.color, u_TriangleColor, colorVal);

        relocatedUV = mul(kaleidUV, createRotationMatrix(-SIXTY_DEGREES / 2.f));
        colorVal = smoothstep(thicknessCheck + AA, thicknessCheck - AA, abs(relocatedUV.x));
        kaleidSampleData.color = lerp(kaleidSampleData.color, u_TriangleColor, colorVal);
    }

    if (u_HexBorderThickness > .0001f) {
        float borderThickness = 1.f - u_HexBorderThickness * .5f;
        float borderVal = smoothstep(borderThickness - AA, borderThickness + AA, kaleidSampleData.uv.y);
        kaleidSampleData.color = lerp(kaleidSampleData.color, u_BorderColor, borderVal);
    }   

    if (u_HexCenterRadius > .0001f) {
        float centerDist = distance(aspectUV, hexCenter);
        float colorVal = smoothstep(u_HexCenterRadius * .5f + AA, 
                                            u_HexCenterRadius * .5f - AA, centerDist);

        kaleidSampleData.color = lerp(kaleidSampleData.color, u_HexCenterColor, colorVal);
    }

    return kaleidSampleData;
}

float4 mainImage( VertData v_in ) : TARGET {
    AspectRatioData aspectRatioData = getAspectRatioData(uv_size);

    KaleidSampleData kaleidSampleData;
    kaleidSampleData.uv = v_in.uv;

    float shortRadius = u_HexRadius * sin(SIXTY_DEGREES);

    float hexGridXIncrement = 1.5f * u_HexRadius;
    float hexGridYIncrement = shortRadius;

    float timeScale = elapsed_time * .5f * u_TimeScaleModifier;

    float4 borderColorAgg = float4(0.f, 0.f, 0.f, 0.f);
    float borderColorVal = 0.f;

    for (int i=0; i<u_KaleidoscopeLevels; i++) {
        float noiseVal = hash(float2(float(i), 0.f));
        kaleidSampleData.uv += float2(sin(timeScale + noiseVal), timeScale);
        kaleidSampleData = getKaleidoscopedUV(
            kaleidSampleData.uv, 
            aspectRatioData, 
            u_HexRadius, 
            shortRadius, 
            SIXTY_DEGREES,
            hexGridXIncrement,
            hexGridYIncrement);

        borderColorAgg += kaleidSampleData.color;
    }
  
    float4 outColor = lerp(image.Sample(textureSampler, kaleidSampleData.uv), borderColorAgg, borderColorAgg.a);
    outColor.a = 1.f;
    return outColor;
}
