

#define MAIN_TRIANGLE_HEIGHT .5f
#define TWOPI 6.28318530718f
#define AA 0.001f
#define SIXTY_DEGREES TWOPI/6.f

uniform float u_TimeScaleModifier = .1f;
uniform float u_HexRadius = .8f;
uniform float u_HexBorderThickness = 0.f;
uniform int u_KaleidoscopeLevels = 2;
uniform float4 u_BorderColor = {1.f, 1.f, 1.f, 1.f};
uniform float u_DebugValue = 0.f;

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

float4 getColorFromValue(float val) {
    return float4(val, 0.f, 0.f, 1.f);
}

// TODO can swap out hexRadius for modifiedHexRadius in caller
float4 getKaleidoscopedUV(float2 uv, 
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

    // TODO bounds of the ortho-hex grid are identified. from there, find appropriate hex center
    // TODO move all points so 0,0 is actually at topRight
    
    float2 leftBottom = float2(leftEdge, bottomEdge);
    float2 leftTop = float2(leftEdge, topEdge);
    float2 rightTop = float2(rightEdge, topEdge);
    float2 rightBottom = float2(rightEdge, bottomEdge);
    
    float aspectHexRadius = hexRadius;
    float2 hexCenter = float2(-1.f, -1.f);

    // TODO Y axis is flipped in HLSL!
    // TODO isHexCenter is working!
    if (isHexCenter(leftBottom, aspectHexGridXIncrement, hexGridYIncrement)) {
        float2 hexDiagRight = leftBottom + float2(aspectHexRadius, 0.f);
        float2 hexDiagLeft = leftTop + float2(aspectHexRadius / 2.f, 0.f);

        if (distance(aspectUV, hexDiagLeft) < .01f || distance(aspectUV, hexDiagRight) < .01f) {
            return getColorFromValue(1.f);
        }

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
        float2 leftTop = float2(leftEdge, topEdge);

        float2 hexDiagRight = leftTop + float2(aspectHexRadius, 0.f);
        float2 hexDiagLeft = rightBottom - float2(aspectHexRadius, 0.f);

        if (distance(aspectUV, hexDiagLeft) < .01f || distance(aspectUV, hexDiagRight) < .01f) {
            return getColorFromValue(1.f);
        }

        
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

    if (distance(aspectUV, hexCenter) < .02f) {
        return float4(0.f, 0.f, 0.f, 1.f);
    }

        
    float offsetAngle = getOffsetAngle(hexCenter, aspectUV);
    // mulitplying by 5 rotates the uv so the default orientation (0 radians) is facing downward
    offsetAngle = fmod(offsetAngle + 5.f * angle, TWOPI);
    
    int offsetIndex = int(round(floor(offsetAngle / angle)));

    float rotation = float(offsetIndex) * angle;
    
    float2x2 rotationMatrix = createRotationMatrix(rotation);

    // TODO calcs are correct until this point


    
    float2 unaspectedHexCenter = mul(hexCenter, aspectRatioData.inverseScaleMatrix);
    float2 kaleidUV = mul((aspectUV - hexCenter), rotationMatrix);
    // kaleidUV should now be above 0,0, within the perfect triangle below 
    // (y flipped in hlsl)
    float aspectRatio = aspectRatioData.aspectRatio;
    float sampleY = kaleidUV.y / shortRadius;
    // this identifies where it is in the triangle, not the image
    float triangleXCoord = (kaleidUV.x + hexRadius / 2.f) / hexRadius; 
    // triangleXCoord is expected value!
    float sampleX = triangleXCoord;

    float imageWidthAtScale = shortRadius * aspectRatio;
    float imageTriangleDelta = imageWidthAtScale - hexRadius;
    sampleX = (imageTriangleDelta / 2.f + triangleXCoord * hexRadius) / imageWidthAtScale;

    if (fmod(offsetIndex, 2) == 1) {
        sampleX = 1.f - sampleX;
    }
    
    return image.Sample(textureSampler, float2(sampleX, sampleY));
}

float4 mainImage( VertData v_in ) : TARGET {
    AspectRatioData aspectRatioData = getAspectRatioData(uv_size);

    float2 kaleidoscopedUV = v_in.uv;

    float shortRadius = u_HexRadius * sin(SIXTY_DEGREES);

    float hexGridXIncrement = 1.5f * u_HexRadius;
    float hexGridYIncrement = shortRadius;

    float timeScale = elapsed_time * .5f * u_TimeScaleModifier;

    for (int i=0; i<u_KaleidoscopeLevels; i++) {
        //kaleidoscopedUV += float2(sin(timeScale), timeScale);
        // kaleidoscopedUV = getKaleidoscopedUV(
        return getKaleidoscopedUV(
            kaleidoscopedUV, 
            aspectRatioData, 
            u_HexRadius, 
            shortRadius, 
            SIXTY_DEGREES,
            hexGridXIncrement,
            hexGridYIncrement);
        if (u_HexBorderThickness > .0001f && kaleidoscopedUV.y > 1.f - u_HexBorderThickness) {
            return u_BorderColor;
        }     
    }
  
    return image.Sample(textureSampler, kaleidoscopedUV);
}
