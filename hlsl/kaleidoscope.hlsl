

#define MAIN_TRIANGLE_HEIGHT .5f
#define TWOPI 6.28318530718f
#define AA 0.001f
#define SIXTY_DEGREES TWOPI/6.f

uniform float u_TimeScaleModifier = .1f;
uniform float u_HexRadius = .8f;
uniform float u_HexBorderThickness = 0.f;
uniform int u_KaleidoscopeLevels = 2;
uniform float4 u_BorderColor = {1.f, 1.f, 1.f, 1.f};

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

// TODO can swap out hexRadius for modifiedHexRadius in caller
float2 getKaleidoscopedUV(float2 uv, 
                        AspectRatioData aspectRatioData, 
                        float modifiedHexRadius, 
                        float shortRadius, 
                        float angle,
                        float hexGridXIncrement,
                        float hexGridYIncrement) 
{
    float2 aspectUV = mul(uv, aspectRatioData.scaleMatrix);
    
    float leftEdge = floor(aspectUV.x / hexGridXIncrement) * hexGridXIncrement;
    float rightEdge = leftEdge + hexGridXIncrement;
    float bottomEdge = floor(aspectUV.y / hexGridYIncrement) * hexGridYIncrement;
    float topEdge = bottomEdge + hexGridYIncrement;
    
    float2 leftBottom = float2(leftEdge, bottomEdge);
    
    float2 hexCenter;
    if (isHexCenter(leftBottom, hexGridXIncrement, hexGridYIncrement)) {
        float2 rightTop = float2(rightEdge, topEdge);
        hexCenter = distance(aspectUV, leftBottom) < distance(aspectUV, rightTop) ? 
            leftBottom : rightTop;
    } else {
        float2 leftTop = float2(leftEdge, topEdge);
        float2 rightBottom = float2(rightEdge, bottomEdge);
        hexCenter = distance(aspectUV, leftTop) < distance(aspectUV, rightBottom) ? 
            leftTop : rightBottom;
    }
    
    float distFromHexCenter = distance(aspectUV, hexCenter);
    
    float offsetAngle = getOffsetAngle(hexCenter, aspectUV);
    // mulitplying by 5 rotates the uv so the default orientation (0 radians) is facing downward
    offsetAngle = fmod(offsetAngle + 5.f * angle, TWOPI);
    
    int offsetIndex = int(round(floor(offsetAngle / angle)));

    float rotation = float(offsetIndex) * angle;
    
    float2x2 rotationMatrix = createRotationMatrix(rotation);
    
    float2 kaleidUV = mul((aspectUV - hexCenter), rotationMatrix);
    // kaleidUV should now be above 0,0, within the perfect triangle below 
    // (y flipped in hlsl)
    float sampleY = kaleidUV.y / shortRadius;
    
    float sampleX = (kaleidUV.x + modifiedHexRadius / 2.f) / modifiedHexRadius;

    if (fmod(offsetIndex, 2) == 1) {
        sampleX = 1.f - sampleX;
    }
    
    return float2(sampleX, sampleY);
}

float4 mainImage( VertData v_in ) : TARGET {
    AspectRatioData aspectRatioData = getAspectRatioData(uv_size);

    float2 kaleidoscopedUV = v_in.uv;

    float shortRadius = u_HexRadius * sin(SIXTY_DEGREES);

    // TODO why does atan(60) work here? found via debugging, investigate
    float modifiedHexRadius = u_HexRadius * atan(SIXTY_DEGREES * 360.f / TWOPI);

    float hexGridXIncrement = 1.5f * u_HexRadius;
    float hexGridYIncrement = shortRadius;

    float timeScale = elapsed_time * .5f * u_TimeScaleModifier;

    for (int i=0; i<u_KaleidoscopeLevels; i++) {
        kaleidoscopedUV += float2(sin(timeScale), timeScale);
        kaleidoscopedUV = getKaleidoscopedUV(
            kaleidoscopedUV, 
            aspectRatioData, 
            modifiedHexRadius, 
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
