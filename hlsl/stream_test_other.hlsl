
#define AA .003f
#define TWOPI 6.28318530718f
// #define GREEN float3(51.f / 255.f, 138.f / 255.f, 36.f / 255.f)
#define iResolution float2(800.f, 540.f)
#define OTHER true

uniform float u_rotationSpeed; // {"material":"Rotation Speed","default":0.05,"range":[0,1]}

float2 rotatePointAroundOtherPoint(float2 center, float2 p, float angleInRadians) {
    float2x2 rotationMatrix = float2x2 (
        cos(angleInRadians), -sin(angleInRadians),
        sin(angleInRadians), cos(angleInRadians)
    );
    
    return (mul((p - center), rotationMatrix)) + center;
}

float4 mainImage( VertData v_in ) : TARGET
{
    float iTime = elapsed_time;
    float2 uv = v_in.uv;
    float aspectRatio = iResolution.x / iResolution.y;
    uv.x *= aspectRatio;

    float2 center = float2(.5f * aspectRatio, .5f);
    
    float bandThickness = .01f;
    float lineThickness = .01f;
    
    float rotationTimeScale = iTime / 60.f;
    
    float dist = distance(center, uv); 
    
    if (true) {
        dist += iTime / 60.f;
    }
    
    int bandIndex = int(floor(dist / bandThickness)) + (OTHER ? 1 : 0);
    float bandStartDist = float(bandIndex) * bandThickness;
    float bandEndDist = bandStartDist + lineThickness;
    float bandCenterDist = bandStartDist + lineThickness * .5f;
    
    float rotationFactor = fmod(float(bandIndex) * rotationTimeScale, TWOPI);
    rotationFactor = sin(iTime) * .2f;

    bool otherBand = fmod(float(bandIndex), 2.f) < .0001f;
    if (otherBand) {
        rotationFactor *= -1.;
    }
    
    rotationFactor = 0.f;
    
    uv = rotatePointAroundOtherPoint(center, uv, rotationFactor);

    float4 texColor = image.Sample(textureSampler, rotatePointAroundOtherPoint(center, v_in.uv, rotationFactor));
    if (otherBand) {
        texColor.r = 0.f;
    } else {
        texColor.a = 0.f;
    }
    
    float3 outColor = texColor.xyz;
    
    // THIS PART IS ONLY REQUIRED IF AA IS NEEDED (when one of the bands is invisible)
    float stepVal = 0.f;
    if (dist > bandCenterDist) {
        stepVal = smoothstep(bandEndDist - AA, bandEndDist + AA, dist);
    } else {
        stepVal = smoothstep(bandStartDist + AA, bandStartDist - AA, dist);
    }
    
    float4 spaceColor = float4(0.f, 0.f, 0.f, 0.f);
    texColor = lerp(texColor, spaceColor, stepVal);
    
    return texColor; 
}