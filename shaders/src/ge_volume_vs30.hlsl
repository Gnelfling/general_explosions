// General Explosions: vertex shader for a cube with 3D UV coordinates.
// Requires Source's standard shader compiler include directory.
// Expected shader name: ge_volume_vs30.vcs
#include "common_vs_fxc.h"

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
    VS_OUTPUT result = (VS_OUTPUT)0;
    float3 world_pos;
    SkinPosition(0, vertex.position, 0, 0, world_pos);
    result.clip_pos = mul(float4(world_pos, 1.0), cViewProj);
    result.uvw = vertex.uvw;
    return result;
}
