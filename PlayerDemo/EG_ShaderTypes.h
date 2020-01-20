//
//  EG_ShaderTypes.h
//  PlayerDemo
//
//  Created by Easer Liu on 2020/1/20.
//  Copyright © 2020 EasyGoing. All rights reserved.
//

#ifndef EG_ShaderTypes_h
#define EG_ShaderTypes_h

#include <simd/simd.h>

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API buffer set calls
typedef enum AAPLVertexInputIndex
{
    AAPLVertexInputIndexVertices     = 0,
    AAPLVertexInputIndexViewportSize = 1,
} AAPLVertexInputIndex;

// Texture index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API texture set calls
typedef enum AAPLTextureIndex
{
    AAPLTextureIndexBaseColor = 0,
} AAPLTextureIndex;

//  This structure defines the layout of each vertex in the array of vertices set as an input to the
//    Metal vertex shader.  Since this header is shared between the .metal shader and C code,
//    you can be sure that the layout of the vertex array in the code matches the layout that
//    the vertex shader expects

typedef struct
{
    // Positions in pixel space. A value of 100 indicates 100 pixels from the origin/center.
    vector_float2 position;

    // 2D texture coordinate
    vector_float2 textureCoordinate;
} AAPLVertex;

typedef struct
{
    vector_float4 position;
    vector_float2 textureCoordinate;
} EGVertex2;

typedef struct {
    matrix_float3x3 matrix;
    vector_float3 offset;
} EGConvertMatrix;
#endif /* EG_ShaderTypes_h */
