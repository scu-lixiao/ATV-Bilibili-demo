//
//  MetalShaders.metal
//  DanmakuKit
//
//  Created by AI Assistant on 2025/11/01.
//  Metal 4 优化：弹幕渲染 Shader
//

#include <metal_stdlib>
using namespace metal;

// 顶点输入结构
struct VertexIn {
    float2 position [[attribute(0)]];  // 顶点位置 (-0.5 ~ 0.5)
    float2 texCoord [[attribute(1)]];  // 纹理坐标 (0 ~ 1)
};

// 实例数据结构（每个弹幕的属性）
struct InstanceData {
    float2 position;       // 弹幕屏幕位置
    float2 size;           // 弹幕尺寸
    float alpha;           // 透明度
    float rotation;        // 旋转角度（预留）
};

// 顶点输出结构
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float alpha;
};

// 顶点着色器（Instanced Drawing）
vertex VertexOut danmaku_vertex(
    VertexIn in [[stage_in]],
    constant InstanceData *instances [[buffer(1)]],
    constant float2 &viewportSize [[buffer(2)]],
    uint instanceID [[instance_id]]
) {
    InstanceData instance = instances[instanceID];
    
    VertexOut out;
    
    // 计算世界空间位置
    float2 worldPos = in.position * instance.size + instance.position;
    
    // 转换到 NDC 空间 (-1 ~ 1)
    float2 ndcPos = worldPos / viewportSize * 2.0 - 1.0;
    ndcPos.y = -ndcPos.y; // 翻转 Y 轴（Metal 坐标系）
    
    out.position = float4(ndcPos, 0.0, 1.0);
    out.texCoord = in.texCoord;
    out.alpha = instance.alpha;
    
    return out;
}

// 片段着色器（纹理采样 + Alpha 混合）
fragment float4 danmaku_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    // 采样纹理
    float4 color = texture.sample(textureSampler, in.texCoord);
    
    // 应用实例透明度
    color.a *= in.alpha;
    
    // 预乘 Alpha（Metal 推荐的混合模式）
    color.rgb *= color.a;
    
    return color;
}

// 高级片段着色器（带模糊效果，使用 MetalFX）
fragment float4 danmaku_fragment_advanced(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler textureSampler [[sampler(0)]],
    constant float &blurAmount [[buffer(0)]]
) {
    float4 color = float4(0.0);
    
    if (blurAmount > 0.0) {
        // 简单的 3x3 高斯模糊（内联权重）
        float kernelSum = 16.0;
        float2 texelSize = 1.0 / float2(texture.get_width(), texture.get_height());
        
        // 手动展开循环避免数组声明
        color += texture.sample(textureSampler, in.texCoord + float2(-1, -1) * texelSize * blurAmount) * 1.0;
        color += texture.sample(textureSampler, in.texCoord + float2( 0, -1) * texelSize * blurAmount) * 2.0;
        color += texture.sample(textureSampler, in.texCoord + float2( 1, -1) * texelSize * blurAmount) * 1.0;
        
        color += texture.sample(textureSampler, in.texCoord + float2(-1,  0) * texelSize * blurAmount) * 2.0;
        color += texture.sample(textureSampler, in.texCoord + float2( 0,  0) * texelSize * blurAmount) * 4.0;
        color += texture.sample(textureSampler, in.texCoord + float2( 1,  0) * texelSize * blurAmount) * 2.0;
        
        color += texture.sample(textureSampler, in.texCoord + float2(-1,  1) * texelSize * blurAmount) * 1.0;
        color += texture.sample(textureSampler, in.texCoord + float2( 0,  1) * texelSize * blurAmount) * 2.0;
        color += texture.sample(textureSampler, in.texCoord + float2( 1,  1) * texelSize * blurAmount) * 1.0;
        
        color /= kernelSum;
    } else {
        color = texture.sample(textureSampler, in.texCoord);
    }
    
    color.a *= in.alpha;
    color.rgb *= color.a;
    
    return color;
}
