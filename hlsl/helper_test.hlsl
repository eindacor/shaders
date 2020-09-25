
#define TWOPI 6.28318530718f

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

float2 rotatePointAroundOtherPoint(float2 center, float2 uv, float angleInRadians) {
    float2x2 rotationMatrix = float2x2 (
        cos(angleInRadians), -sin(angleInRadians),
        sin(angleInRadians), cos(angleInRadians)
    );
    
    return (mul((uv - center), rotationMatrix)) + center;
}

// float getColorValFromUVAndTriangleLine(float2 uv, float2 p1, float2, p2, float2 p3, float antiAlias) {
//     for (int i=0; i<3; i++) {
//         float
//     }
// }

float2x2 createRotationMatrix(float angleInRadians) {
    return float2x2 (
        cos(angleInRadians), -sin(angleInRadians),
        sin(angleInRadians), cos(angleInRadians)
    );
}

float getColorValFromUVAndTriangleSolid(float2 uv, float2 p1, float2 p2, float2 p3, float antiAlias) {
    float colorVal = 1.f;
    for (int i=0; i<3; i++) {
        float2 edgeStart = (i == 0 ? p1 : (i == 1 ? p2 : p3));
        float2 edgeEnd = (i == 0 ? p2 : (i == 1 ? p3 : p1));
        float2 oppositePoint = (i == 0 ? p3 : (i == 1 ? p1 : p2));

        float rotation = getAngleBetweenPoints(edgeStart, edgeEnd);
        float2x2 rotationMatrix = createRotationMatrix(rotation);

        float2 modifiedEnd = mul(edgeEnd - edgeStart, rotationMatrix);
        float2 modifiedOpp = mul(oppositePoint - edgeStart, rotationMatrix);
        float2 modifiedUV = mul(uv - edgeStart, rotationMatrix);

        // flip these just to avoid duplicate antiAlias code 
        if (modifiedOpp.y > 0.f) {
            modifiedOpp.y *= -1.f;
            modifiedUV.y *= -1.f;
        }
        if (modifiedEnd.x < 0.f) {
            modifiedEnd.x *= -1.f;
            modifiedUV.x *= -1.f;
        }

        colorVal *= smoothstep(-modifiedOpp.y + antiAlias, 
                                -modifiedOpp.y - antiAlias, 
                                modifiedUV.y - modifiedOpp.y);
        
        // when antiAlias is amplified this does some odd chopping, though not noticible when subtle
        // this prevents the edges from having long extensions for acute angles
        if (modifiedUV.y > 0.f) {
            if (modifiedUV.x > modifiedEnd.x) {
                colorVal *= smoothstep(modifiedEnd.x + antiAlias, modifiedEnd.x, modifiedUV.x);
            } else if (modifiedUV.x < 0.f) {
                colorVal *= smoothstep(-antiAlias, 0.f, modifiedUV.x);
            }
        }
    }

    return colorVal;
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

float getColorValFromUVAndLineSegmentRoundEnd(float2 uv, float2 start, float2 end, float lineThickness, float antiAlias) {
    float angle = getAngleBetweenPoints(start, end);

    float2 modifiedUV = rotatePointAroundOtherPoint(float2(0.f, 0.f), uv - start, angle);
    float halfThickness = lineThickness / 2.f;

    float colorVal = 1.f;

    if (modifiedUV.x < 0.f) {
        colorVal *= smoothstep(halfThickness + antiAlias, halfThickness - antiAlias, distance(modifiedUV, float2(0.f, 0.f)));
    } else if (modifiedUV.x > distance(start, end)) {
        //colorVal = smoothstep(distance(start, end) + antiAlias * 2.f, distance(start, end), modifiedUV.x);
    }

    if (modifiedUV.y < 0.f) {
        colorVal *= smoothstep(-halfThickness - antiAlias, -halfThickness + antiAlias, modifiedUV.y);
    } else {
        colorVal *= smoothstep(halfThickness + antiAlias, halfThickness - antiAlias, modifiedUV.y);
    }

    return colorVal;
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


float4 mainImage( VertData v_in ) : TARGET {
    float2 p1 = float2(0.5f, 0.5f);
    float2 p2 = float2(0.55f, 0.75f);
    float2 p3 = float2(0.75f, 0.85f);

    p3 = rotatePointAroundOtherPoint(p1, p3, elapsed_time * .5f);
    p3 = p1 + float2(0.5f, 0.f);

    if (distance(v_in.uv, p1) < .01f ||
        distance(v_in.uv, p2) < .01f ||
        distance(v_in.uv, p3) < .01f) {
        return float4(1.f, 0.f, 1.f, 1.f);
    }


    return lerp(float4(0.f, 0.f, 0.f, 1.f), float4(1.f, 1.f, 1.f, 1.f),
        getColorValFromUVAndLineSegmentRoundEnd(v_in.uv, p1, p3, .3f, .01f));

    // return lerp(float4(0.f, 0.f, 0.f, 1.f), float4(1.f, 1.f, 1.f, 1.f), 
    //     getColorValFromUVAndTriangleSolid(v_in.uv, p1, p2, p3, .002f));
}