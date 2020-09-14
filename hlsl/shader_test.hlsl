
#define WINDOW_DIVISIONS 4

uniform float u_LineThickness = .001f;
uniform float4 u_BackgroundColor = {1.f, 1.f, 1.f, 1.f};


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

float4 getReturnColor(float2 uv) {
    return float4(uv.x, uv.y, .5f, 1.f);
}

float4 mainImage( VertData v_in ) : TARGET {
    float2 uv = v_in.uv;

    float lineFrequency = 1.f / float(WINDOW_DIVISIONS);
    AspectRatioData aspectRatioData = getAspectRatioData(uv_size);

    float nearestX = round(uv.x / lineFrequency) * lineFrequency;
    float nearestY = round(uv.y / lineFrequency) * lineFrequency;
    if (abs(nearestX - uv.x) < u_LineThickness / aspectRatioData.aspectRatio || abs(nearestY - uv.y) < u_LineThickness) {
        return getReturnColor(uv);
    }

    return u_BackgroundColor;
}