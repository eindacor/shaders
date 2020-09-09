
#define TWOPI 6.28318530718f
#define AA .001f
#define HEIGHT_VARIABILITY 1.f

/*
    for each neighbor in light's direction
    take inverse light vector, scale by height difference
    if uv offset by that vector lands on this neighbor, uv
    is in shadow
*/

uniform float u_LightOrientation = 1.f;
uniform float u_TileSize = .2f;
uniform float u_ShadowIntensity = .8f;

struct AspectRatioMatrices {
    float2x2 scaleMatrix;
    float2x2 inverseScaleMatrix;
};

AspectRatioMatrices getAspectRatioMatrices(float2 uvSize) {
    float aspectRatio = uvSize.x / uvSize.y;
    AspectRatioMatrices aspectRatioMatrices;
    aspectRatioMatrices.scaleMatrix = float2x2(
        aspectRatio, 0.f,
        0.f, 1.f
    );
    
    aspectRatioMatrices.inverseScaleMatrix = float2x2(
        1.f / aspectRatio, 0.f,
        0.f, 1.f
    );

    return aspectRatioMatrices;
}

float2 getTileCoords(float2 uv) {
    return float2(floor(uv.x / u_TileSize) * u_TileSize, 
        floor(uv.y / u_TileSize) * u_TileSize);
}

// from https://www.shadertoy.com/view/4djSRW
float hash(float2 p)
{
    float val = sin(dot(p, float2(12.9898f, 78.233f))) * 43758.5453f;
    return val - floor(val);
}

float getTileHeight(float2 coords) {
    return hash(coords) * u_TileSize;
}

// https://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect
bool linesIntersect(float4 first, float4 second)
{
    float2 p0 = float2(first.x, first.y);
    float2 p1 = float2(first.z, first.a);
    float2 p2 = float2(second.x, second.y);
    float2 p3 = float2(second.z, second.a);

    float2 s1 = float2(p1.x - p0.x, p1.y - p0.y);
    float2 s2 = float2(p3.x - p2.x, p3.y - p2.y);

    float s = (-s1.y * (p0.x - p2.x) + s1.x * (p0.y - p2.y)) / (-s2.x * s1.y + s1.x * s2.y);
    float t = ( s2.x * (p0.y - p2.y) - s2.y * (p0.x - p2.x)) / (-s2.x * s1.y + s1.x * s2.y);

    return (s >= 0.f && s <= 1.f && t >= 0.f && t <= 1.f);
}

float4 mainImage( VertData v_in ) : TARGET {
    float2 uv = v_in.uv;
    uv.y = 1.f - uv.y;
    float rotation = u_LightOrientation * TWOPI;
    float2x2 rotationMatrix = float2x2(
        cos(rotation), -sin(rotation),
        sin(rotation), cos(rotation)
    );

    float2 lightOrientation = mul(float2(0.f, u_TileSize * .5f), rotationMatrix);
    float2 normalizedLightVec = normalize(lightOrientation);

    AspectRatioMatrices aspectRatioMatrices = getAspectRatioMatrices(uv_size);

    float2 aspectRatioUV = mul(uv, aspectRatioMatrices.scaleMatrix);

    float2 thisTile = getTileCoords(aspectRatioUV);
    float tileHeight = getTileHeight(thisTile);

    if (distance(aspectRatioUV, thisTile) < .01f) {
        return float4(1.f, 1.f, 1.f, 1.f);
    }

    if (aspectRatioUV.y < thisTile.y + u_TileSize * tileHeight) {
        return float4(1.f, 0.f, 0.f, 1.f);
    }

    float lineThickness = .01f;
    if (abs(aspectRatioUV.x - thisTile.x) < lineThickness || 
        abs(aspectRatioUV.x - thisTile.x + u_TileSize) < lineThickness ||
        abs(aspectRatioUV.y - thisTile.y) < lineThickness || 
        abs(aspectRatioUV.y - thisTile.y + u_TileSize) < lineThickness) {
        return float4(0.f, 0.f, 0.f, 1.f);
    }


    //TODO identify neighbors in light's direction

    float4 outColor = image.Sample(textureSampler, v_in.uv);
    for (int i=0; i<4; i++) {
        float2 sampleUV = aspectRatioUV + lightOrientation;
        float2 sampleTile = getTileCoords(sampleUV);
        if (sampleTile.x == thisTile.x && sampleTile.y == thisTile.y) {
            continue;
        }

        float sampleTileHeight = getTileHeight(sampleTile);
        if (sampleTileHeight < tileHeight) {
            continue;
        }

        float2 scaledLightVec = normalizedLightVec * sampleTileHeight - tileHeight;
        float2 lightLineEnd = aspectRatioUV + scaledLightVec;    
        float4 uvToLightLine = float4(aspectRatioUV.x, aspectRatioUV.y, lightLineEnd.x, lightLineEnd.y);

        // see if scaled light vec intersects any edges of the neighbor tile
        // TODO find a better way to do this
        float4 sampleTileEdge0 = float4(sampleTile.x, sampleTile.y, sampleTile.x, sampleTile.y + u_TileSize);
        if (linesIntersect(sampleTileEdge0, uvToLightLine)) {
            outColor *= (1.f - u_ShadowIntensity);
            outColor.a = 1.f;
            return outColor;
        }

        float4 sampleTileEdge1 = float4(sampleTile.x, sampleTile.y, sampleTile.x + u_TileSize, sampleTile.y);
        if (linesIntersect(sampleTileEdge1, uvToLightLine)) {
            outColor *= (1.f - u_ShadowIntensity);
            outColor.a = 1.f;
            return outColor;
        }

        float4 sampleTileEdge2 = float4(sampleTile.x, sampleTile.y + u_TileSize, sampleTile.x + u_TileSize, sampleTile.y + u_TileSize);
        if (linesIntersect(sampleTileEdge2, uvToLightLine)) {
            outColor *= (1.f - u_ShadowIntensity);
            outColor.a = 1.f;
            return outColor;
        }

        float4 sampleTileEdge3 = float4(sampleTile.x + u_TileSize, sampleTile.y + u_TileSize, sampleTile.x + u_TileSize, sampleTile.y);
        if (linesIntersect(sampleTileEdge3, uvToLightLine)) {
            outColor *= (1.f - u_ShadowIntensity);
            outColor.a = 1.f;
            return outColor;
        }
    }

    return outColor;
}