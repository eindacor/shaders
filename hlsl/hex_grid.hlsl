


#define MAIN_TRIANGLE_HEIGHT .5f
#define TWOPI 6.28318530718f
#define AA 0.0015f
#define SIXTY_DEGREES 1.0471975512f
#define SCALE_LINE_WEIGHT false

uniform float u_TimeScaleModifier = .1f;
uniform float u_HexRadius = .8f;
uniform float u_HexBorderThickness = 0.f;
uniform float u_HexTriangleThickness = 0.f;
uniform float u_HexCenterRadius = 0.f;
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

float2 getHexCenter(float2 aspectUV, 
                    float hexGridXIncrement, 
                    float hexGridYIncrement,
                    float hexRadius) {

    float leftEdge = floor(aspectUV.x / hexGridXIncrement) * hexGridXIncrement;
    float rightEdge = leftEdge + hexGridXIncrement;
    float bottomEdge = floor(aspectUV.y / hexGridYIncrement) * hexGridYIncrement;
    float topEdge = bottomEdge + hexGridYIncrement;
    
    float2 leftBottom = float2(leftEdge, bottomEdge);
    float2 leftTop = float2(leftEdge, topEdge);

    float2 hexCenter = float2(-1.f, -1.f); 

    if (isHexCenter(leftBottom, hexGridXIncrement, hexGridYIncrement)) {
        float2 rightTop = float2(rightEdge, topEdge);
        float2 hexDiagRight = leftBottom + float2(hexRadius, 0.f);
        float2 hexDiagLeft = leftTop + float2(hexRadius / 2.f, 0.f);
        float2 sharedEdgeVector = float2(hexDiagLeft - hexDiagRight);
        float2 sharedToRightTopVector = float2(rightTop - hexDiagRight);
        float2 sharedToUVVector = float2(aspectUV - hexDiagRight);

        float3 crossRightTop = cross(float2ToFloat3(sharedEdgeVector), 
                                    float2ToFloat3(sharedToRightTopVector));
        float3 crossUV = cross(float2ToFloat3(sharedEdgeVector), 
                                float2ToFloat3(sharedToUVVector));

        hexCenter = (crossRightTop.z == crossUV.z) || 
            (crossRightTop.z < 0.f && crossUV.z < 0.f) || 
            (crossRightTop.z > 0.f && crossUV.z > 0.f) ? rightTop : leftBottom;
    } else {
        float2 rightBottom = float2(rightEdge, bottomEdge);
        float2 hexDiagRight = leftTop + float2(hexRadius, 0.f);
        float2 hexDiagLeft = rightBottom - float2(hexRadius, 0.f);
        float2 sharedEdgeVector = float2(hexDiagRight - hexDiagLeft);
        float2 sharedToRightBottomVector = float2(rightBottom - hexDiagLeft);
        float2 sharedToUVVector = float2(aspectUV - hexDiagLeft);

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

// to make a new hex grid shader, replace the code in here to get a color from the uv
// within the hexagod. (0,0) is at the center of the hex, (0,1) is top, (0,-1) is bottom
float4 getColorFromHexUV(float2 hexUV, float hexRadius, float scale) {
    float offsetAngle = getOffsetAngle(float2(0.f, 0.f), hexUV);
    // mulitplying by 5 rotates the uv so the default orientation (0 radians) is facing downward
    offsetAngle = fmod(offsetAngle + 5.f * SIXTY_DEGREES, TWOPI);

    int offsetIndex = int(round(floor(offsetAngle / SIXTY_DEGREES)));
    float rotation = float(offsetIndex) * SIXTY_DEGREES;
    // triangleUV is below 0,0 (upper left) with the perfect triangle "above"
    // (or below, y flipped in hlsl)
    float2 triangleUV = mul(hexUV, createRotationMatrix(rotation));

    float4 outColor = float4(0.f, 0.f, 0.f, 0.f);

    float scaledAA = AA * scale;
    float scaleCoeff = .1f;

    if (u_HexTriangleThickness > .0001f) {
        float triangleTestRotationMatrix = createRotationMatrix(-SIXTY_DEGREES / 2.f);
        float thicknessCheck = u_HexTriangleThickness;
        if (SCALE_LINE_WEIGHT) {
            thicknessCheck *= scale * scaleCoeff;
        }

        float2 relocatedUV = mul(triangleUV, createRotationMatrix(-SIXTY_DEGREES / 2.f));
        float colorVal = smoothstep(thicknessCheck + scaledAA, thicknessCheck - scaledAA, abs(relocatedUV.x));
        outColor = lerp(outColor, u_TriangleColor, colorVal);

        relocatedUV = mul(triangleUV, createRotationMatrix(SIXTY_DEGREES / 2.f));
        colorVal = smoothstep(thicknessCheck + scaledAA, thicknessCheck - scaledAA, abs(relocatedUV.x));
        outColor = lerp(outColor, u_TriangleColor, colorVal);
    }

    if (u_HexBorderThickness > .0001f) {
        float borderThickness = u_HexBorderThickness;
        if (SCALE_LINE_WEIGHT) {
            borderThickness *= scale * scaleCoeff;
        }

        float borderVal = smoothstep(borderThickness + scaledAA, borderThickness - scaledAA, 1.f - triangleUV.y);
        outColor = lerp(outColor, u_BorderColor, borderVal);
    }   

    if (u_HexCenterRadius > .0001f) {
        float centerDist = distance(hexUV, float2(0.f, 0.f));
        float radiusCheck = u_HexCenterRadius;
        if (SCALE_LINE_WEIGHT) {
            radiusCheck *= scale * scaleCoeff;
        }

        float colorVal = smoothstep(radiusCheck + scaledAA, radiusCheck - scaledAA, centerDist);

        outColor = lerp(outColor, u_HexCenterColor, colorVal);
    }

    return outColor;
}

float4 getColorFromHexGrid(float2 uv, 
                        AspectRatioData aspectRatioData, 
                        float hexRadius, 
                        float shortRadius, 
                        float hexGridXIncrement,
                        float hexGridYIncrement) 
{
    float2 aspectUV = mul(uv, aspectRatioData.scaleMatrix);

    float2 hexCenter = getHexCenter(aspectUV,
                            hexGridXIncrement, 
                            hexGridYIncrement,
                            hexRadius);

    float offsetAngle = getOffsetAngle(hexCenter, aspectUV);
    // mulitplying by 5 rotates the uv so the default orientation (0 radians) is facing downward
    offsetAngle = fmod(offsetAngle + 5.f * SIXTY_DEGREES, TWOPI);

    // hexUV is the uv oriented as if the hexCenter was 0,0
    float2 hexUV = (aspectUV - hexCenter);

    float scale = 1.f / shortRadius;
    float2x2 scaleMatrix = float2x2(
        scale, 0.f,
        0.f, scale
    );

    // scale to make shortRadius = 1, so top edge is at 1 and bottom is -1
    return getColorFromHexUV(mul(hexUV, scaleMatrix), hexRadius, scale);
}

float4 mainImage( VertData v_in ) : TARGET {
    AspectRatioData aspectRatioData = getAspectRatioData(uv_size);

    float timeScale = elapsed_time * .5f * u_TimeScaleModifier;
    float2 uv = v_in.uv + float2(sin(timeScale), timeScale);

    float shortRadius = u_HexRadius * sin(SIXTY_DEGREES);

    float hexGridXIncrement = 1.5f * u_HexRadius;
    float hexGridYIncrement = shortRadius;

    float4 borderColorAgg = float4(0.f, 0.f, 0.f, 0.f);
    float borderColorVal = 0.f;

    float4 outColor = getColorFromHexGrid(
        uv, 
        aspectRatioData, 
        u_HexRadius, 
        shortRadius, 
        hexGridXIncrement,
        hexGridYIncrement);
  
    outColor.a = 1.f;
    return outColor;
}
