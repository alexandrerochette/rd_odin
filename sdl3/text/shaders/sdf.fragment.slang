Texture2D    font_texture;
SamplerState font_sampler;


struct StageAttributes {
    float4 pos : SV_Position;
    float2 uv;
};


[shader("fragment")]
float4 FSMain(StageAttributes input) : SV_Target {
    float dist = font_texture.Sample(font_sampler, input.uv).a;
    float smoothing = fwidth(dist);
    float alpha = smoothstep(0.5 - smoothing, 0.5 + smoothing, dist);
    return float4(0.0, 1.0, 1.0, alpha);
}