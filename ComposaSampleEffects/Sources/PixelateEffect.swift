import Foundation
import ComposaSDK

/// ピクセル化エフェクト。映像をブロック状に粗くする。
struct PixelateEffect: EffectShader {
    let id = "sample.pixelate"
    let name = "Pixelate"
    let fragmentFunctionName = "pixelateFragment"
    let parameters = [
        EffectParameter(id: "size", label: "Block Size", defaultValue: 10, min: 1, max: 100),
    ]
    var fragmentShaderSource: String {
        SampleEffectShaderHeader.header + """
        fragment float4 pixelateFragment(VertexOut in [[stage_in]],
                                          texture2d<float> tex [[texture(0)]],
                                          constant float *params [[buffer(0)]]) {
            float blockSize = params[0];
            float2 texSize = float2(tex.get_width(), tex.get_height());
            float2 blockCount = texSize / max(blockSize, 1.0);
            float2 uv = floor(in.texCoord * blockCount) / blockCount;
            constexpr sampler s(filter::linear);
            return tex.sample(s, uv);
        }
        """
    }
}
