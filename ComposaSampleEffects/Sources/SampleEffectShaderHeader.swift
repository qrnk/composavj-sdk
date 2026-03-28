import Foundation

/// サンプルエフェクト共通の Metal シェーダーヘッダ。
enum SampleEffectShaderHeader {
    static let header = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOut {
        float4 position [[position]];
        float2 texCoord;
    };

    vertex VertexOut effectVertex(uint vid [[vertex_id]]) {
        float2 positions[6] = {
            float2(-1, -1), float2(1, -1), float2(-1, 1),
            float2(-1, 1), float2(1, -1), float2(1, 1)
        };
        float2 texCoords[6] = {
            float2(0, 1), float2(1, 1), float2(0, 0),
            float2(0, 0), float2(1, 1), float2(1, 0)
        };
        VertexOut out;
        out.position = float4(positions[vid], 0, 1);
        out.texCoord = texCoords[vid];
        return out;
    }

    """
}
