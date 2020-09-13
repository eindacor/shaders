

#define MAIN_TRIANGLE_HEIGHT .5f
#define TWOPI 6.28318530718f

uniform float u_TimeScaleModifier = .1f;
uniform float u_ScaleModifier = .5f;
uniform int u_KaleidoscopeLevels = 2;

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

float2 getKaleidoscopedUV(float2 uv, AspectRatioData aspectRatioData) {
    float timeScale = elapsed_time * .5f * u_TimeScaleModifier;
    uv += float2(2.f, -1.f);
    uv += float2(sin(timeScale), timeScale);

    float2 aspectUV = mul(uv, aspectRatioData.scaleMatrix);
    
    float hexRadius = 1.f * u_ScaleModifier;
    float sixtyDegrees = TWOPI / 6.f;
    float shortRadius = hexRadius * sin(sixtyDegrees);
    
    float hexGridXIncrement = 1.5f * hexRadius;
    float hexGridYIncrement = shortRadius;
    
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
    offsetAngle = fmod(offsetAngle + 5.f * sixtyDegrees, TWOPI);
    
    int offsetIndex = int(round(floor(offsetAngle / sixtyDegrees)));

    bool mirror = fmod(offsetIndex, 2) == 1;
    float rotation = float(offsetIndex) * sixtyDegrees;
    
    float2x2 rotationMatrix = createRotationMatrix(rotation);
    
    float2 kaleidUV = mul((aspectUV - hexCenter), rotationMatrix);
    // kaleidUV should now be above 0,0, within the perfect triangle below 
    // (y flipped in hlsl)
    float sampleY = kaleidUV.y / shortRadius;
    
    // code below essentially gets its x sample value from the interpolation 
    // between one side of the perfect triangle to the other,
    // the translates that to the image's uv space
    float xDist = shortRadius / tan(sixtyDegrees) * aspectRatioData.aspectRatio;
    float delta = xDist * 2.f;
    float valueDelta = kaleidUV.x + xDist;
    float sampleX = valueDelta / delta;

    if (mirror) {
        sampleX = 1.f - sampleX;
    }
    
    return float2(sampleX, sampleY);
}

float4 mainImage( VertData v_in ) : TARGET {
    AspectRatioData aspectRatioData = getAspectRatioData(uv_size);

    float2 kaleidoscopedUV = v_in.uv;

    for (int i=0; i<u_KaleidoscopeLevels; i++) {
        kaleidoscopedUV = getKaleidoscopedUV(kaleidoscopedUV, aspectRatioData);
    }
    
    return image.Sample(textureSampler, kaleidoscopedUV);
}
