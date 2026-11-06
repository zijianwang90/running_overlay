#include <metal_stdlib>
using namespace metal;

struct RasterVertex { float4 position [[position]]; float2 uv; };

vertex RasterVertex overlayVertex(uint index [[vertex_id]]) {
    constexpr float2 positions[] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
    float2 p = positions[index];
    return { float4(p, 0, 1), float2((p.x + 1) * 0.5, (1 - p.y) * 0.5) };
}

// Host adapter only: both inputs are already premultiplied. This diagnostic
// does not certify host working-space/HDR conversion for the overlay plane.
fragment float4 overlayComposite(
    RasterVertex in [[stage_in]], texture2d<float> source [[texture(0)]],
    texture2d<float> overlay [[texture(1)]], constant bool &flipOverlay [[buffer(0)]]) {
    constexpr sampler sampleFilter(coord::normalized, address::clamp_to_edge, filter::nearest);
    float4 base = source.sample(sampleFilter, in.uv);
    float2 overlayUV = float2(in.uv.x, flipOverlay ? 1 - in.uv.y : in.uv.y);
    float4 over = overlay.sample(sampleFilter, overlayUV);
    return over + base * (1 - over.a);
}
