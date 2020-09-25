

#define MAIN_TRIANGLE_HEIGHT .5f
#define TWOPI 6.28318530718f
#define AA 0.0015f
#define SIXTY_DEGREES 1.0471975512f
#define SCALE_LINE_WEIGHT false

uniform float u_TimeScaleModifier = .1f;
uniform float u_HexRadius = .8f;
uniform float u_HexBorderThickness = 0.f;
uniform float u_HexTriangleThickness = 0.f;
uniform float u_LineThickness = .1f;
uniform float4 u_BorderColor = {1.f, 1.f, 1.f, 1.f};
uniform float4 u_LineColor = {1.f, 1.f, 1.f, 1.f};

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

// (0,0) is at the center of the hex, (0,1) is top, (0,-1) is bottom
float4 getColorFromHexUV(float2 hexUV, float hexRadius, float scale, float randomSeed, int lineCount) {
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

    if (hash(float2(randomSeed, float(offsetIndex))) < .5) {
        float colorVal;
        if (triangleUV.x < 0.f) {
            colorVal = smoothstep(-u_LineThickness - AA, -u_LineThickness + AA, triangleUV.x);
        } else {
            colorVal = smoothstep(u_LineThickness + AA, u_LineThickness - AA, triangleUV.x);
        }
        outColor = lerp(outColor, u_LineColor, colorVal);
    }

    if (u_HexBorderThickness > .0001f) {
        float borderThickness = u_HexBorderThickness;
        if (SCALE_LINE_WEIGHT) {
            borderThickness *= scale * scaleCoeff;
        }

        float borderVal = smoothstep(borderThickness + scaledAA, borderThickness - scaledAA, 1.f - triangleUV.y);
        outColor = lerp(outColor, u_BorderColor, borderVal);
    }   

    return outColor;
}

float2 getLocalHexPointFromHexCenter(float2 hexCenter, float shortRadius) {
    float distFromCenter = hash(hexCenter) * shortRadius;
    float rotation = hash(float2(hexCenter.y, hexCenter.x)) * TWOPI;
    float2x2 rotationMatrix = createRotationMatrix(rotation);
    return hexCenter + mul(float2(0.f, distFromCenter), rotationMatrix);
}

float2 rotatePointAroundOtherPoint(float2 center, float2 p, float angleInRadians) {
    float2x2 rotationMatrix = float2x2 (
        cos(angleInRadians), -sin(angleInRadians),
        sin(angleInRadians), cos(angleInRadians)
    );
    
    return (mul((p - center), rotationMatrix)) + center;
}

float getColorValFromUVAndLine(float2 uv, float2 start, float2 end, float lineThickness) {
    float2 offsetVec = end - start;
    float angle = atan(offsetVec.y / offsetVec.x);
    
    if (start.x > end.x) {
        angle = TWOPI / 2.f + angle;
    } else if (start.y > end.y) {
        angle = TWOPI + angle;
    }

    float2 modifiedUV = rotatePointAroundOtherPoint(float2(0.f, 0.f), uv - start, angle);
    float halfThickness = lineThickness / 2.f;

    if (modifiedUV.x < 0.f || modifiedUV.x > distance(start, end)) {
        return 0.f;
    }

    if (abs(modifiedUV.y) > lineThickness) {
        return 0.f;
    } else {
        return 1.f;
    }

    if (modifiedUV.y < start.y) {
        return smoothstep(-halfThickness - AA, -halfThickness + AA, modifiedUV.y);
    } else {
        return smoothstep(halfThickness + AA, halfThickness - AA, modifiedUV.y);
    }
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

    float2 hexNeighborPoints[6];

    float2 hexPoint = getLocalHexPointFromHexCenter(hexCenter, shortRadius);

    float2 neighborOffset = float2(0.f, shortRadius * 2.f);
    float4 outColor = float4(0.f, 0.f, 0.f, 0.f);
    for (int i=0; i<6; i++) {
        //float rotation = fmod(5.f * SIXTY_DEGREES + float(i) * SIXTY_DEGREES, TWOPI);
        float rotation = TWOPI / 6.f * float(i);
        float2x2 rotationMatrix = createRotationMatrix(rotation);
        float2 neighborHexPoint = getLocalHexPointFromHexCenter(hexCenter + mul(neighborOffset, rotationMatrix), shortRadius);
        float colorVal = getColorValFromUVAndLine(aspectUV, hexPoint, neighborHexPoint, u_LineThickness * .2f);
        outColor = lerp(outColor, u_LineColor, colorVal);
    }

    if (distance(hexPoint, aspectUV) < .005) {
        return float4(1.f, 1.f, 0.f, 1.f);
    }

    return outColor;


    // TODO get random number seed for hex, pick a random number from 1-3
    // TODO based on that number, make a line from center to outside middle for
    // TODO N different triangles

    // float randomSeed = hash(hexCenter);
    // int lineCount = int(randomSeed * 3.f);

    // float offsetAngle = getOffsetAngle(hexCenter, aspectUV);
    // // mulitplying by 5 rotates the uv so the default orientation (0 radians) is facing downward
    // offsetAngle = fmod(offsetAngle + 5.f * SIXTY_DEGREES, TWOPI);

    // // hexUV is the uv oriented as if the hexCenter was 0,0
    // float2 hexUV = (aspectUV - hexCenter);

    // float scale = 1.f / shortRadius;
    // float2x2 scaleMatrix = float2x2(
    //     scale, 0.f,
    //     0.f, scale
    // );

    // // scale to make shortRadius = 1, so top edge is at 1 and bottom is -1
    // return getColorFromHexUV(mul(hexUV, scaleMatrix), hexRadius, scale, randomSeed, lineCount);
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

    //return float4(uv.x, uv.y, 0.f, 1.f);

    float2 center = float2(.5f, .5f);
    float2 test = rotatePointAroundOtherPoint(center, float2(.5f, .75f), elapsed_time);
    if (distance(test, uv) < .01f) {
        return float4(0.f, 1.f, 0.f, 1.f);
    }

    //float angle = asin(uv.y - test.y / distance(test, uv));

    float endPoint = float2(1.f, 1.f);
    endPoint = rotatePointAroundOtherPoint(float2(0.5f, 0.5f), endPoint, .1f);
    //endPoint += elapsed_time * float2(0.1f, 0.1f);

    return float4(
        getColorValFromUVAndLine(uv, center, test, u_LineThickness),
        0.f, 0.f, 1.f
    );

    //return float4(angle, 0.f, 0.f, 1.f);

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
