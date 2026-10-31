// General Explosions: vertex shader for a cube with 3D UV coordinates.
// Self-contained Shader Model 3.0 HLSL; no Source SDK include files required.
// c4-c7: Source model-view-projection matrix (verify binding in GMod).
// IMPORTANT: shader compilation and runtime binding are not yet validated.

float4x4 cModelViewProj : register(c4);

struct VS_INPUT
{
    float4 position : POSITION;
    float3 uvw      : TEXCOORD0;
};

struct VS_OUTPUT
{
    float4 clip_pos : POSITION;
    float3 uvw      : TEXCOORD0;
};

VS_OUTPUT main(VS_INPUT vertex)
{
    VS_OUTPUT result;
    result.clip_pos = mul(vertex.position, cModelViewProj);
    result.uvw = vertex.uvw;
    return result;
}
