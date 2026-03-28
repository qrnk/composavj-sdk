import Foundation
import ComposaSDK

/// スライドトランジション。A が左にスライドアウトし、B が右からスライドインする。
struct SlideTransition: TransitionShader {
    let id = "sample.slide"
    let name = "Slide"
    let controlType: TransitionControlType = .smooth
    let fragmentFunctionName = "slideTransitionFragment"
    var fragmentShaderSource: String {
        SampleTransitionShaderHeader.header + """
        fragment float4 slideTransitionFragment(VertexOut in [[stage_in]],
                                                 texture2d<float> texA [[texture(0)]],
                                                 texture2d<float> texB [[texture(1)]],
                                                 constant float &progress [[buffer(0)]]) {
            constexpr sampler s(filter::linear);
            float p = progress;
            float2 uv = in.texCoord;

            // 境界位置
            float boundary = 1.0 - p;

            if (uv.x < boundary) {
                // A 側: 右にオフセット
                float2 uvA = float2(uv.x + p, uv.y);
                return texA.sample(s, uvA);
            } else {
                // B 側: 左からスライドイン
                float2 uvB = float2(uv.x - boundary, uv.y);
                return texB.sample(s, uvB);
            }
        }
        """
    }
}
