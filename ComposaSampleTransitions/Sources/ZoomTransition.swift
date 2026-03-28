import Foundation
import ComposaSDK

/// ズームイントランジション。A がズームアウトしながら B にフェードする。
struct ZoomTransition: TransitionShader {
    let id = "sample.zoom"
    let name = "Zoom"
    let controlType: TransitionControlType = .smooth
    let fragmentFunctionName = "zoomTransitionFragment"
    var fragmentShaderSource: String {
        SampleTransitionShaderHeader.header + """
        fragment float4 zoomTransitionFragment(VertexOut in [[stage_in]],
                                                texture2d<float> texA [[texture(0)]],
                                                texture2d<float> texB [[texture(1)]],
                                                constant float &progress [[buffer(0)]]) {
            constexpr sampler s(filter::linear);
            float p = progress;

            // A: ズームアウト（中心から縮小）
            float scaleA = 1.0 + p * 0.5;
            float2 uvA = (in.texCoord - 0.5) * scaleA + 0.5;

            // B: ズームイン（拡大から等倍へ）
            float scaleB = 1.5 - p * 0.5;
            float2 uvB = (in.texCoord - 0.5) * scaleB + 0.5;

            float4 colorA = texA.sample(s, uvA);
            float4 colorB = texB.sample(s, uvB);

            return mix(colorA, colorB, p);
        }
        """
    }
}
