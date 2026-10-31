// General Explosions: GPU ray-marched real 3D smoke + fire.
// Shader Model 3.0 / Direct3D 9. Source's screenspace_general material.
// D3D9 constant registers c0-c3 are provided by the GMod material.
//
// c0: camera position in local [0,1] box xyz; absorption coefficient w
// c1: directional light (local XYZ, normalized); target step count w
// c2: density decode scale x; flame decode scale y; flame gain z; ambient w
// c3: smoke tint RGB; effect fade w
//
// s0: VTF 3D texture (R = normalized density, G = normalized flames)
// IMPORTANT: this is authored HLSL. It has NOT been compiled or run in GMod.

sampler3D BASETEXTURE : register(s0);

float4 C0 : register(c0);
float4 C1 : register(c1);
float4 C2 : register(c2);
float4 C3 : register(c3);

struct PS_INPUT
{
    float3 uvw : TEXCOORD0;
};

float4 main(PS_INPUT input) : COLOR0
{
    float3 camera = C0.xyz;
    float3 direction = normalize(input.uvw - camera);

    // Ray / unit-cube slab intersection. A small epsilon keeps axes stable.
    float3 safe_direction = direction + float3(
        (abs(direction.x) < 0.00001) ? 0.00001 : 0.0,
        (abs(direction.y) < 0.00001) ? 0.00001 : 0.0,
        (abs(direction.z) < 0.00001) ? 0.00001 : 0.0);
    float3 inv_direction = 1.0 / safe_direction;
    float3 a = (float3(0.0, 0.0, 0.0) - camera) * inv_direction;
    float3 b = (float3(1.0, 1.0, 1.0) - camera) * inv_direction;
    float3 lo = min(a, b);
    float3 hi = max(a, b);

    float near_t = max(0.0, max(lo.x, max(lo.y, lo.z)));
    float far_t = min(hi.x, min(hi.y, hi.z));
    if (far_t <= near_t)
        return float4(0.0, 0.0, 0.0, 0.0);

    const int MAX_STEPS = 96;
    int steps = (int)clamp(C1.w, 8.0, (float)MAX_STEPS);
    float delta = (far_t - near_t) / (float)steps;
    float3 sun_direction = normalize(C1.xyz);

    float3 accumulated = float3(0.0, 0.0, 0.0);
    float transmittance = 1.0;

    [loop]
    for (int i = 0; i < MAX_STEPS; i++)
    {
        if (i >= steps)
            break;

        float t = near_t + (i + 0.5) * delta;
        float3 uvw = saturate(camera + direction * t);
        float4 voxel = tex3Dlod(BASETEXTURE, float4(uvw, 0.0));

        float density = max(0.0, voxel.r * C2.x);
        float flame = max(0.0, voxel.g * C2.y);
        if (density + flame < 0.0005)
            continue;

        // Cheap directional attenuation via a short look-ahead into the
        // volume. This is single-scattering-inspired, not full path tracing.
        float3 probe = saturate(uvw + sun_direction * 0.07);
        float ahead = tex3Dlod(BASETEXTURE, float4(probe, 0.0)).r * C2.x;
        float skylight = saturate(C2.w);
        float sunlight = exp(-ahead * 2.0);
        float illumination = skylight + (1.0 - skylight) * sunlight;

        float3 smoke_color = C3.xyz * illumination;
        float3 fire_color = lerp(float3(2.4, 0.34, 0.03),
                                float3(2.8, 1.2, 0.27), saturate(flame * 2.0));
        float emission_weight = saturate(flame * C2.z);

        float3 color = smoke_color + fire_color * emission_weight;

        // Beer-Lambert absorption and front-to-back compositing.
        // Flames also contribute to the local opacity.
        float extinction = (density + flame * 0.28) * max(C0.w, 0.0);
        float local_alpha = 1.0 - exp(-extinction * delta);
        accumulated += transmittance * local_alpha * color;
        transmittance *= 1.0 - local_alpha;
        if (transmittance < 0.008)
            break;
    }

    float alpha = saturate((1.0 - transmittance) * C3.w);
    // screenspace_general uses SRC_ALPHA / ONE_MINUS_SRC_ALPHA.
    // Undo premultiplication for that blend mode.
    float3 straight_color = accumulated / max(1.0 - transmittance, 0.0001);
    return float4(saturate(straight_color), alpha);
}
