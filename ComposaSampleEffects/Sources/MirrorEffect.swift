import Foundation
import ComposaSDK

/// ミラーエフェクト。映像を左右または上下に反転・コピーする。
struct MirrorEffect: EffectShader {
    let id = "sample.mirror"
    let name = "Mirror"
    let fragmentFunctionName = "mirrorFragment"
    let parameters = [
        EffectParameter(id: "axis", label: "Axis", defaultValue: 0, min: 0, max: 1),
        EffectParameter(id: "flip", label: "Flip Side", defaultValue: 0, min: 0, max: 1),
    ]
    var fragmentShaderSource: String {
        SampleEffectShaderHeader.header + """
        fragment float4 mirrorFragment(VertexOut in [[stage_in]],
                                        texture2d<float> tex [[texture(0)]],
                                        constant float *params [[buffer(0)]]) {
            float axis = params[0];   // 0 = horizontal, 1 = vertical
            float flip = params[1];   // 0 = left/top, 1 = right/bottom
            float2 uv = in.texCoord;

            if (axis < 0.5) {
                // Horizontal mirror
                if (flip < 0.5) {
                    uv.x = uv.x < 0.5 ? uv.x : 1.0 - uv.x;
                } else {
                    uv.x = uv.x > 0.5 ? uv.x : 1.0 - uv.x;
                }
            } else {
                // Vertical mirror
                if (flip < 0.5) {
                    uv.y = uv.y < 0.5 ? uv.y : 1.0 - uv.y;
                } else {
                    uv.y = uv.y > 0.5 ? uv.y : 1.0 - uv.y;
                }
            }

            constexpr sampler s(filter::linear);
            return tex.sample(s, uv);
        }
        """
    }
}
