
#define TWOPI 6.28318530718f

// from https://www.shadertoy.com/view/4djSRW
float hash(float2 p)
{
    float val = sin(dot(p, float2(12.9898f, 78.233f))) * 43758.5453f;
    return val - floor(val);
}

bool uvIsWithinBounds(float2 uv) {
    return uv.x >= 0.f && uv.x <= 1.f &&
        uv.y >= 0.f && uv.y <= 1.f;
}

float normalizeSinOrCos(float value) {
    return (value + 1.f) / 2.f;
}

float getBrightness(float3 color) {
    return (color.r * 0.2126f + color.g * 0.7152f + color.b * 0.0722f);
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

float2x2 createRotationMatrix(float angleInRadians) {
    return float2x2 (
        cos(angleInRadians), -sin(angleInRadians),
        sin(angleInRadians), cos(angleInRadians)
    );
}

float2 rotatePointAroundOtherPoint(float2 center, float2 uv, float angleInRadians) {
    float2x2 rotationMatrix = float2x2 (
        cos(angleInRadians), -sin(angleInRadians),
        sin(angleInRadians), cos(angleInRadians)
    );
    
    return (mul((uv - center), rotationMatrix)) + center;
}

float getAngleBetweenPoints(float2 first, float2 second) {
    float2 offsetVec = second - first;
    float angle = atan(offsetVec.y / offsetVec.x);
    
    if (first.x > second.x) {
        angle = 3.14159265359f + angle;
    } else if (first.y > second.y) {
        angle = 6.28318530718f + angle;
    }
    
    return angle;
}

float getColorValFromUVAndCircleSolid(float2 uv, float2 circleCenter, float radius, float antiAlias) {
    return smoothstep(radius + antiAlias, radius - antiAlias, distance(uv, circleCenter));
}

// orientation: -1 = radius is outside edge, 0 = radius is centerline, 1 = radius is inside edge
float getColorValFromUVAndCircleLine(float2 uv, 
                                    float2 circleCenter, 
                                    float radius, 
                                    float thickness,
                                    int orientation, 
                                    float antiAlias) 
{
    float centerline;
    float halfThickness = thickness / 2.f;

    if (orientation == 0) {
        centerline = radius;
    } else if (orientation < 0) {
        centerline = radius - halfThickness;
    } else {
        centerline = radius + halfThickness;
    }

    float distanceFromCenter = distance(uv, circleCenter);
    if (distanceFromCenter > centerline) {
        return smoothstep(centerline + halfThickness + antiAlias, 
                        centerline + halfThickness - antiAlias,
                        distanceFromCenter);
    } else {
        return smoothstep(centerline - halfThickness - antiAlias, 
                        centerline - halfThickness + antiAlias,
                        distanceFromCenter);
    }
}

float getColorValFromUVAndLineSegmentFlatEnd(float2 uv, float2 start, float2 end, float lineThickness, float antiAlias) {
    float angle = getAngleBetweenPoints(start, end);

    float2 modifiedUV = rotatePointAroundOtherPoint(float2(0.f, 0.f), uv - start, angle);
    float halfThickness = lineThickness / 2.f;

    float colorVal = 1.f;

    if (modifiedUV.x < 0.f) {
        colorVal *= smoothstep(-antiAlias * 2.f, 0.f, modifiedUV.x);
    } else if (modifiedUV.x > distance(start, end)) {
        colorVal = smoothstep(distance(start, end) + antiAlias * 2.f, distance(start, end), modifiedUV.x);
    }

    if (modifiedUV.y < 0.f) {
        colorVal *= smoothstep(-halfThickness - antiAlias, -halfThickness + antiAlias, modifiedUV.y);
    } else {
        colorVal *= smoothstep(halfThickness + antiAlias, halfThickness - antiAlias, modifiedUV.y);
    }

    return colorVal;
}

float getColorValFromUVAndLineSegmentRoundEnd(float2 uv, float2 start, float2 end, float lineThickness, float antiAlias) {
    // can be replaced by angle = getAngleBetweenPoints(start, end)
    float2 offsetVec = end - start;
    float angle = atan(offsetVec.y / offsetVec.x);
    
    if (start.x > end.x) {
        angle = TWOPI / 2.f + angle;
    } else if (start.y > end.y) {
        angle = TWOPI + angle;
    }
    // end of replace-able code

    float2 modifiedUV = rotatePointAroundOtherPoint(float2(0.f, 0.f), uv - start, angle);
    float halfThickness = lineThickness / 2.f;

    if (modifiedUV.x < 0.f || modifiedUV.x > distance(start, end)) {
        return 0.f;
    }

    

    if (modifiedUV.y < start.y) {
        return smoothstep(-halfThickness - antiAlias, -halfThickness + antiAlias, modifiedUV.y);
    } else {
        return smoothstep(halfThickness + antiAlias, halfThickness - antiAlias, modifiedUV.y);
    }
}

float getColorValFromUVAndTriangleSolid(float2 uv, float2 p1, float2, p2, float2 p3, float antiAlias) {

}