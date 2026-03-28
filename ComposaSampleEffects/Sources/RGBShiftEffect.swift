import Foundation
import ComposaSDK

/// RGB 色ズレエフェクト。R/G/B チャンネルを個別にオフセットする。
struct RGBShiftEffect: EffectShader {
    let id = "sample.rgbshift"
    let name = "RGB Shift"
    let fragmentFunctionName = "rgbShiftFragment"
    let parameters = [
        EffectParameter(id: "amount", label: "Amount", defaultValue: 5, min: 0, max: 50),
        EffectParameter(id: "angle", label: "Angle", defaultValue: 0, min: 0, max: 360),
    ]
    var fragmentShaderSource: String {
        SampleEffectShaderHeader.header + """
        fragment float4 rgbShiftFragment(VertexOut in [[stage_in]],
                                          texture2d<float> tex [[texture(0)]],
                                          constant float *params [[buffer(0)]]) {
            float amount = params[0];
            float angle = params[1] * 3.14159265 / 180.0;
            float2 texSize = float2(tex.get_width(), tex.get_height());
            float2 offset = float2(cos(angle), sin(angle)) * amount / texSize;

            constexpr sampler s(filter::linear);
            float r = tex.sample(s, in.texCoord + offset).r;
            float g = tex.sample(s, in.texCoord).g;
            float b = tex.sample(s, in.texCoord - offset).b;
            float a = tex.sample(s, in.texCoord).a;
            return float4(r, g, b, a);
        }
        """
    }
}
