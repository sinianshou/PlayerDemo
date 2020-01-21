//
//  EG_Shaders.metal
//  PlayerDemo
//
//  Created by Easer Liu on 2020/1/20.
//  Copyright © 2020 EasyGoing. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;



// Include header shared between this Metal shader code and C code executing Metal API commands
#import "EG_ShaderTypes.h"

typedef struct
{
    // The [[position]] attribute qualifier of this member indicates this value is
    // the clip space position of the vertex when this structure is returned from
    // the vertex shader
    // position的修饰符表示这个是顶点
    float4 position [[position]];

    // Since this member does not have a special attribute qualifier, the rasterizer
    // will interpolate its value with values of other vertices making up the triangle
    // and pass that interpolated value to the fragment shader for each fragment in
    // that triangle.
    // 纹理坐标，会做插值处理
    float2 textureCoordinate;

} RasterizerData;

// Vertex Function
//vertex RasterizerData
//aplvertexShader(uint vertexID [[ vertex_id ]],
//             constant EGVertex1 *vertexArray [[ buffer(EGVertex1InputIndexVertices) ]],
//             constant vector_uint2 *viewportSizePointer  [[ buffer(EGVertex1InputIndexViewportSize) ]])
//
//{
//
//    RasterizerData out;
//
//    // Index into the array of positions to get the current vertex.
//    //   Positions are specified in pixel dimensions (i.e. a value of 100 is 100 pixels from
//    //   the origin)
//    float2 pixelSpacePosition = vertexArray[vertexID].position.xy;
//
//    // Get the viewport size and cast to float.
//    float2 viewportSize = float2(*viewportSizePointer);
//
//    // To convert from positions in pixel space to positions in clip-space,
//    //  divide the pixel coordinates by half the size of the viewport.
//    // Z is set to 0.0 and w to 1.0 because this is 2D sample.
//    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
//    out.position.xy = pixelSpacePosition / (viewportSize / 2.0);
//
//    // Pass the input textureCoordinate straight to the output RasterizerData. This value will be
//    //   interpolated with the other textureCoordinate values in the vertices that make up the
//    //   triangle.
//    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
//
//    return out;
//}


// Fragment function
fragment float4
aplsamplingShader(RasterizerData in [[stage_in]],
               texture2d<half> colorTexture [[ texture(EGTextureIndexBaseColor) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);

    // Sample the texture to obtain a color
    const half4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);

    // return the color of the texture
    return float4(colorSample);
}

//From LY
// Vertex Function
vertex RasterizerData
lyvertexShader(uint vertexID [[ vertex_id ]], // vertex_id是顶点shader每次处理的index，用于定位当前的顶点
             constant EGVertex *vertexArray [[ buffer(EGVertex1InputIndexVertices) ]]) { // buffer表明是缓存数据，0是索引
    RasterizerData out;
    out.position = vertexArray[vertexID].position;
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    return out;
}
// Fragment function
fragment float4
lysamplingShader(RasterizerData input [[stage_in]], // stage_in表示这个数据来自光栅化。（光栅化是顶点处理之后的步骤，业务层无法修改）
               texture2d<float> textureY [[ texture(EGFragmentTextureIndexTextureY) ]], // texture表明是纹理数据，EGFragmentTextureIndexTextureY是索引
               texture2d<float> textureUV [[ texture(EGFragmentTextureIndexTextureUV) ]], // texture表明是纹理数据，EGFragmentTextureIndexTextureUV是索引
               constant EGConvertMatrix *convertMatrix [[ buffer(EGFragmentInputIndexMatrix) ]]) //buffer表明是缓存数据，EGFragmentInputIndexMatrix是索引
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear); // sampler是采样器

    float3 yuv = float3(textureY.sample(textureSampler, input.textureCoordinate).r,
                          textureUV.sample(textureSampler, input.textureCoordinate).rg);

    float3 rgb = convertMatrix->matrix * (yuv + convertMatrix->offset);

    return float4(rgb, 1.0);
    
}


fragment half4
halfsamplingShader(RasterizerData in [[ stage_in ]],
               texture2d<float> lumaTexture [[ texture(0) ]],
               texture2d<float> chromaTexture [[ texture(1) ]],
               sampler textureSampler [[ sampler(0) ]],
               constant float3x3 *yuvToRGBMatrix [[ buffer(0) ]])
{
    float3 yuv;
    yuv.x = lumaTexture.sample(textureSampler, in.textureCoordinate).r - float(0.062745);
    yuv.yz = chromaTexture.sample(textureSampler, in.textureCoordinate).rg - float2(0.5);
    return half4(half3((*yuvToRGBMatrix) * yuv), yuv.x);
}
