Texture2D    font_texture;
SamplerState font_sampler;

struct TransformData {
    row_major float4x4 mvp;   
};
ConstantBuffer<TransformData> transform;

struct VSInput {
    [[vk::location(0)]] float2 pos;
    [[vk::location(1)]] float2 uv;
};

struct StageAttributes {
    float4 pos : SV_Position;
    float2 uv;
};

[shader("vertex")]
StageAttributes VSMain(VSInput input) {
    StageAttributes output;
    output.pos = mul(transform.mvp, float4(input.pos, 0.0, 1.0));
    output.uv  = input.uv;
    return output;
}

[shader("fragment")]
float4 FSMain(StageAttributes input) : SV_Target {
    float alpha = font_texture.Sample(font_sampler, input.uv).a;
    return float4(1, 1, 1, alpha);
}