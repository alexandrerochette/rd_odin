Texture2D    font_texture;
SamplerState font_sampler;


struct FragmentsGlobalData {
    float4 color;
    float1 u_weight;
    float3 padding;
};
ConstantBuffer<FragmentsGlobalData> fragmentsGlobal;


struct StageAttributes {
    float4 pos : SV_Position;
  
    float2 uv;
};


[shader("fragment")]
float4 FSMain(StageAttributes input) : SV_Target {
    float dist = font_texture.Sample(font_sampler, input.uv).a;
 
    float smoothing = fwidth(dist);
    float threshold = 0.5;
    float alpha = smoothstep(threshold - smoothing, threshold + smoothing, dist);

 
    return float4(1.0, 1.0, 1.0, alpha) * fragmentsGlobal.color;

  
}


