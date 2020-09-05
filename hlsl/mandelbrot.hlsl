
uniform float u_RotationSpeed; // {"material":"Rotation Speed","default":1,"range":[0,1]}
uniform float u_ColorChangeSpeed; // {"material":"Color Change Speed","default":1,"range":[0,1]}
uniform float u_ZoomSpeed; // {"material":"Zoom Speed","default":1,"range":[0,1]}
uniform float u_InversionFactor; // {"material":"Inversion Factor","default":0,"range":[0,1]}
uniform float u_RChannel; // {"material":"R Channel","default":1,"range":[0,1]}
uniform float u_GChannel; // {"material":"G Channel","default":1,"range":[0,1]}
uniform float u_BChannel; // {"material":"B Channel","default":1,"range":[0,1]}

#define antiAlias 2

float normalizeInputVal(float value) {
    return (value + 1000.f) / 2000.f;
}


float getMagnification(float currentTime) 
{
    float totalZoomTime = 21.f;
    float timeScale = normalizeInputVal(u_ZoomSpeed) * .5f;
    float adjustedTime = currentTime * timeScale;
  
    float zoomTime = fmod(adjustedTime, totalZoomTime);
    if (int(fmod(adjustedTime / totalZoomTime, 2.f)) == 1) {
        zoomTime = totalZoomTime - zoomTime;
    }
    
    return pow(2.f, zoomTime);
}

float2 getRotatedPosition(float currentTime, float2 graphPosition) 
{
    float rotationSpeed = normalizeInputVal(u_RotationSpeed) * .1f;
    float viewRotationTime = currentTime * rotationSpeed;
    float2x2 viewRotationMatrix = float2x2(
        cos(viewRotationTime), -sin(viewRotationTime),
        sin(viewRotationTime), cos(viewRotationTime)
    );
    return mul(viewRotationMatrix, float2(graphPosition.x, graphPosition.y));
}

float2 getNewZ(float2 z, float2 c) {
    float newY = 2.f * z.x * z.y + c.y;
    float newX = (z.x * z.x) + (z.y * z.y * -1.f) + c.x;
    return float2(newX, newY);
}

int getIterationsBeforeExplosion(float2 pos, int iterationLimit) 
{
    float magnitudeThreshold = 2.f;
    float realValue = pos.x;
    float imaginaryValue = pos.y;
    float2 z = float2(0.f, 0.f);
    for (int i = 0; i < iterationLimit; i++) {
        z = getNewZ(z, pos);
        if (distance(z, float2(0.f, 0.f)) > magnitudeThreshold) {
            return i;   
        }
    }   
    return iterationLimit;
}

float3 getColor(float value) {
    float3 red = float3(1.f, 0.f, 0.f);
    float3 green = float3(0.f, 1.f, 0.f);
    float3 blue = float3(0.f, 0.f, 1.f);
    
    if (value < .5f) {
        return lerp(blue, green, value * 2.f);
    } else {
        return lerp(green, red, (value - .5f) * 2.f);
    }   
}

float3 rotateColor(float3 color, float time) {
    float3 deNormalized = (color * 2.f) - float3(1.f, 1.f, 1.f);
    
    float timeFactor = time * normalizeInputVal(u_ColorChangeSpeed);

    float xRotationTime = timeFactor / 2.1f;
    float yRotationTime = timeFactor / 2.3f;
    float zRotationTime = timeFactor / 2.5f;
    
    float3x3 rotationXMatrix = float3x3(
        1.f, 0.f, 0.f,
        0.f, cos(xRotationTime), -sin(xRotationTime),
        0.f, sin(xRotationTime), cos(xRotationTime)
    ); 
    
    float3x3 rotationYMatrix = float3x3(
        cos(yRotationTime), 0.f, sin(yRotationTime),
        0.f, 1.f, 0.f,
        -sin(yRotationTime), 0.f, cos(yRotationTime)
    );
    
    float3x3 rotationZMatrix = float3x3(
        cos(zRotationTime), -sin(zRotationTime), 0.f,
        sin(zRotationTime), cos(zRotationTime), 0.f,
        0.f, 0.f, 1.f
    );
    
    float3 rotated = mul(rotationXMatrix, mul(rotationYMatrix, mul(rotationZMatrix, deNormalized)));
    return (rotated + float3(1.f, 1.f, 1.f)) / 2.f;
}

float4 getAAPosColor(float2 screenResolution, int iterationLimit, float2 texUv, float aspectRatio, float2 focalPoint, float time) {
    float4 outColor = float4(1.f, 1.f, 1.f, 1.f);
    for (int m=0; m<antiAlias; m++) {
        for (int n=0; n<antiAlias; n++) {
            float2 uv = (texUv * screenResolution + float2(float(m), float(n))/float(antiAlias))/screenResolution;

            float2 graphPosition = (uv * 2.f - float2(1.f, 1.f)) / getMagnification(time);

            graphPosition.x *= aspectRatio; 
            graphPosition = getRotatedPosition(time, graphPosition);
            graphPosition += focalPoint;
     
            int stableIterations = getIterationsBeforeExplosion(graphPosition, iterationLimit);
            
            if (stableIterations >= iterationLimit) {
                outColor += float4(0.f, 0.f, 0.f, 0.f);
            } else {
                float3 rotatedColor = rotateColor(float3(getColor(float(stableIterations) / float(iterationLimit))), time);
                outColor += float4(rotatedColor.r, rotatedColor.g, rotatedColor.b, 1.f);
            }
        }
    }

    return outColor/float(antiAlias*antiAlias);
}

float4 mainImage( VertData v_in ) : TARGET
{
    float2 screenResolution = float2(float(uv_size.x), float(uv_size.y));
    float aspectRatio = uv_size.x / uv_size.y;
    float2 focalPoint = float2(0.0495f, .655f);
    focalPoint = float2(0.2008f, .555f);
    int iterationLimit = 200;
    
    float4 outColor = getAAPosColor(screenResolution, iterationLimit, v_in.uv, aspectRatio, focalPoint, elapsed_time);

    outColor = float4(outColor * float4(normalizeInputVal(u_RChannel), normalizeInputVal(u_GChannel), normalizeInputVal(u_BChannel), 1.f));
    float3 invertedColor = lerp(outColor.rgb, float3(1.f, 1.f, 1.f) - outColor.rgb, normalizeInputVal(u_InversionFactor));
    return float4(invertedColor, outColor.a);
}
