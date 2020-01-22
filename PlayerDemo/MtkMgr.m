//
//  MtkMgr.m
//  PlayerDemo
//
//  Created by Easer Liu on 2020/1/19.
//  Copyright © 2020 EasyGoing. All rights reserved.
//

typedef enum{
    MediaTypeNone=0,
    MediaTypeImage,
    MediaTypeVideo,
    MediaTypeAudio,
} MediaType;

#import "MtkMgr.h"
#import "m3u8Test.h"

// Header shared between C code here, which executes Metal API commands, and .metal files, which
//   uses these types as inputs to the shaders
#import "EG_ShaderTypes.h"
static MtkMgr *_oneSharedMM;

@interface MtkMgr ()<MTKViewDelegate>{
    MTKView *_mtkView;
}

@property (nonatomic, strong) NSURL* fileUrl;
@property (nonatomic, assign) MediaType mediaType;
@property (nonatomic, assign) CVMetalTextureCacheRef textureCache;

// data
@property (nonatomic, assign) vector_uint2 viewportSize;
@property (nonatomic, strong) id<MTLTexture> texture;
@property (nonatomic, strong) id<MTLBuffer> vertices;
@property (nonatomic, strong) id<MTLBuffer> convertMatrix;
@property (nonatomic, assign) NSUInteger numVertices;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
// The command Queue used to submit commands.
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;

@end
@implementation MtkMgr
+ (instancetype)shared{
    if (!_oneSharedMM) {
        _oneSharedMM = [[MtkMgr alloc] init];
    }
    return _oneSharedMM;
}
+ (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView{
    MtkMgr * mgr = [MtkMgr shared];
    mgr.mtkView = mtkView;
    return mgr;
}
- (void)initMtkView{
    _mtkView.device = MTLCreateSystemDefaultDevice();
    _mtkView.preferredFramesPerSecond = 30;
    NSAssert(_mtkView.device, @"Metal is not supported on this device");
    CVMetalTextureCacheCreate(NULL, NULL, _mtkView.device, NULL, &_textureCache); // TextureCache的创建
    [self setupPipeline];
    [self setupVertex];
    [self setupMatrix];
}

- (void)setupMatrix { // 设置好转换的矩阵
    matrix_float3x3 kColorConversion601FullRangeMatrix = (matrix_float3x3){
        (simd_float3){1.0,    1.0,    1.0},
        (simd_float3){0.0,    -0.343, 1.765},
        (simd_float3){1.4,    -0.711, 0.0},
    };
    
    vector_float3 kColorConversion601FullRangeOffset = (vector_float3){ -(16.0/255.0), -0.5, -0.5}; // 这个是偏移
    
    EGConvertMatrix matrix;
    // 设置参数
    matrix.matrix = kColorConversion601FullRangeMatrix;
    matrix.offset = kColorConversion601FullRangeOffset;
    
    self.convertMatrix = [self.mtkView.device newBufferWithBytes:&matrix
                                                          length:sizeof(EGConvertMatrix)
                                                         options:MTLResourceStorageModeShared];
}
// 设置渲染管道
-(void)setupPipeline {
    
    /// Create the render pipeline.

    // Load the shaders from the default library
    NSString * prefix = @"ly";
    id<MTLLibrary> defaultLibrary = [self.mtkView.device newDefaultLibrary];
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"lyvertexShader"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:[prefix stringByAppendingString:@"samplingShader"]];

    // Set up a descriptor for creating a pipeline state object
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"Texturing Pipeline";
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat;

    NSError *error = NULL;
    self.pipelineState = [self.mtkView.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                             error:&error];

    NSAssert(self.pipelineState, @"Failed to created pipeline state, error %@", error);
    
    self.commandQueue = [self.mtkView.device newCommandQueue]; // CommandQueue是渲染指令队列，保证渲染指令有序地提交到GPU
}
// 设置顶点
- (void)setupVertex {
    
    // Set up a simple MTLBuffer with vertices which include texture coordinates
//    static const EGVertex1 quadVertices[] =
//    {
//        // Pixel positions, Texture coordinates
//        { {  250,  -250 },  { 1.f, 1.f } },
//        { { -250,  -250 },  { 0.f, 1.f } },
//        { { -250,   250 },  { 0.f, 0.f } },
//
//        { {  250,  -250 },  { 1.f, 1.f } },
//        { { -250,   250 },  { 0.f, 0.f } },
//        { {  250,   250 },  { 1.f, 0.f } },
//    };

        static const EGVertex quadVertices[] =
        {   // 顶点坐标，分别是x、y、z、w；    纹理坐标，x、y；
            { {  1.0, -1.0, 0.0, 1.0 },  { 1.f, 1.f } },
            { { -1.0, -1.0, 0.0, 1.0 },  { 0.f, 1.f } },
            { { -1.0,  1.0, 0.0, 1.0 },  { 0.f, 0.f } },

            { {  1.0, -1.0, 0.0, 1.0 },  { 1.f, 1.f } },
            { { -1.0,  1.0, 0.0, 1.0 },  { 0.f, 0.f } },
            { {  1.0,  1.0, 0.0, 1.0 },  { 1.f, 0.f } },
        };
    
    // Create a vertex buffer, and initialize it with the quadVertices array
    self.vertices = [_mtkView.device newBufferWithBytes:quadVertices
                                     length:sizeof(quadVertices)
                                    options:MTLResourceStorageModeShared];

    // Calculate the number of vertices by dividing the byte length by the size of each vertex
    self.numVertices = sizeof(quadVertices) / sizeof(EGVertex);
    
}
- (void)displayImageFile: (NSURL *) url{
    NSString * fileExtension = url.pathExtension;
    if ([fileExtension  isEqual: @"jpeg"] || [fileExtension  isEqual: @"png"]) {
        self.mediaType = MediaTypeImage;
    }else if ([fileExtension  isEqual: @"mp4"]){
        self.mediaType = MediaTypeVideo;
    }else{
        NSLog(@"file not support");
        return;
    }
    self.fileUrl = url;
    self.mtkView.delegate = self;
    [self mtkView:self.mtkView drawableSizeWillChange:self.mtkView.drawableSize];
}
- (id<MTLTexture>)loadTextureWithImageFile: (NSURL *) url {
//    NSData * data = [NSData dataWithContentsOfURL:url];
//    UIImage * image = [UIImage imageWithData:data];
//
//    self.mtkView.drawableSize = image.size;
//    NSLog(@"size is %f, %f, %f, %f,", self.mtkView.drawableSize.height, self.mtkView.drawableSize.width, image.size.height,image.size.width);
//    NSError *err = nil;
//    MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:self.mtkView.device];
//    id<MTLTexture> texture = [textureLoader newTextureWithCGImage:image.CGImage options:@{MTKTextureLoaderOptionSRGB: @NO} error:&err];
    
    CVPixelBufferRef buffer = [self pixelBufferFromImageFile:url];
    id<MTLTexture> texture = [self getImgTextures:buffer];
    
    return texture;
}


- (CVPixelBufferRef) pixelBufferFromImageFile: (NSURL *) url
{
    NSData * data = [NSData dataWithContentsOfURL:url];
    CGImageRef image = [UIImage imageWithData:data].CGImage;
    NSDictionary *options = @{
                              (NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES,
                              (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
                              (NSString*)kCVPixelBufferIOSurfacePropertiesKey: [NSDictionary dictionary]
                              };
    CVPixelBufferRef pxbuffer = NULL;
    
    CGFloat frameWidth = CGImageGetWidth(image);
    CGFloat frameHeight = CGImageGetHeight(image);
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          frameWidth,
                                          frameHeight,
//                                          kCVPixelFormatType_32BGRA,
                                          kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 frameWidth,
                                                 frameHeight,
                                                 8,
                                                 CVPixelBufferGetBytesPerRow(pxbuffer),
                                                 rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformIdentity);
    CGContextDrawImage(context, CGRectMake(0,
                                           0,
                                           frameWidth,
                                           frameHeight),
                       image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}
- (id<MTLTexture>)getImgTextures:(CVPixelBufferRef) pixelBuffer{
    
    NSAssert(pixelBuffer, @"pixelBuffer is nil");
    id<MTLTexture> textureY = nil;
    // textureY 设置
    {
        size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        MTLPixelFormat pixelFormat = MTLPixelFormatR8Unorm; // 这里的颜色格式不是RGBA

        CVMetalTextureRef texture = NULL; // CoreVideo的Metal纹理
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache, pixelBuffer, NULL, pixelFormat, width, height, 0, &texture);
        if(status == kCVReturnSuccess)
        {
            textureY = CVMetalTextureGetTexture(texture); // 转成Metal用的纹理
            CFRelease(texture);
        }
    }
    
    return textureY;
}
- (NSMutableArray<id<MTLTexture>> *)getVideoTextures:(CVPixelBufferRef) pixelBuffer{
    NSMutableArray<id<MTLTexture>> * texArr = [[NSMutableArray alloc] init];
    
    NSAssert(pixelBuffer, @"pixelBuffer is nil");
    id<MTLTexture> textureY = nil;
    id<MTLTexture> textureUV = nil;
    // textureY 设置
    {
        size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        MTLPixelFormat pixelFormat = MTLPixelFormatR8Unorm; // 这里的颜色格式不是RGBA

        CVMetalTextureRef texture = NULL; // CoreVideo的Metal纹理
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache, pixelBuffer, NULL, pixelFormat, width, height, 0, &texture);
        if(status == kCVReturnSuccess)
        {
            textureY = CVMetalTextureGetTexture(texture); // 转成Metal用的纹理
            CFRelease(texture);
        }
    }
    
    // textureUV 设置
    {
        size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
        MTLPixelFormat pixelFormat = MTLPixelFormatRG8Unorm; // 2-8bit的格式
        
        CVMetalTextureRef texture = NULL; // CoreVideo的Metal纹理
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache, pixelBuffer, NULL, pixelFormat, width, height, 1, &texture);
        if(status == kCVReturnSuccess)
        {
            textureUV = CVMetalTextureGetTexture(texture); // 转成Metal用的纹理
            CFRelease(texture);
        }
    }
    
    if(textureY != nil && textureUV != nil)
    {
        [texArr addObject:textureY];
        [texArr addObject:textureUV];
//        [encoder setFragmentTexture:textureY
//                            atIndex:EGFragmentTextureIndexTextureY]; // 设置纹理
//        [encoder setFragmentTexture:textureUV
//                            atIndex:EGFragmentTextureIndexTextureUV]; // 设置纹理
    }
    if (textureY.width != self.mtkView.frame.size.width) {
        
        self.mtkView.frame = CGRectMake(0, 0, self.mtkView.frame.size.width, self.mtkView.frame.size.width * textureY.height / textureY.width);
    }
    return texArr;
}
#pragma __SETTER__
- (void)setMtkView:(MTKView *)mtkView{
    _mtkView = mtkView;
    [self initMtkView];
}

#pragma __GETTER__
- (MTKView *)mtkView{
    if (!_mtkView) {
        _mtkView = [[MTKView alloc] init];
        [self initMtkView];
    }
    return _mtkView;
}
-(id<MTLTexture>)texture{
    if (!_texture) {
        _texture = [self loadTextureWithImageFile:self.fileUrl];
    }
    return _texture;
}
#pragma __MTKViewDelegate__
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    self.viewportSize = (vector_uint2){size.width, size.height};
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    if (!self.fileUrl || self.mediaType == MediaTypeNone) {
        return;
    }
    // Create a new command buffer for each render pass to the current drawable
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    
    
    // Obtain a renderPassDescriptor generated from the view's drawable textures
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if(renderPassDescriptor != nil)
    {
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.5, 0.5, 1.0f); // 设置默认颜色
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        // Set the region of the drawable to draw into.
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, self.viewportSize.x, self.viewportSize.y, -1.0, 1.0 }];

        [renderEncoder setRenderPipelineState:self.pipelineState];

        [renderEncoder setVertexBuffer:self.vertices
                                offset:0
                              atIndex:EGVertex1InputIndexVertices];
        
        [renderEncoder setFragmentBuffer:self.convertMatrix
                                  offset:0
                                 atIndex:EGFragmentInputIndexMatrix];
        
        [renderEncoder setVertexBytes:&_viewportSize
                               length:sizeof(_viewportSize)
                              atIndex:EGVertex1InputIndexViewportSize];

        // Set the texture object.  The EGTextureIndexBaseColor enum value corresponds
        ///  to the 'colorMap' argument in the 'samplingShader' function because its
        //   texture attribute qualifier also uses EGTextureIndexBaseColor for its index.
        NSMutableArray<id<MTLTexture>> * texArr = [[NSMutableArray alloc] init];
        CVPixelBufferRef pixelBuffer = NULL;
        switch (self.mediaType) {
            case MediaTypeImage:
                [texArr addObject:self.texture];
                break;
            case MediaTypeNone:
                break;
            case MediaTypeVideo:
            case MediaTypeAudio:

                pixelBuffer = [self.m3u8T getBuffer]; // 从CMSampleBuffer读取CVPixelBuffer，
            [texArr addObjectsFromArray:[self getVideoTextures:pixelBuffer]];
                break;
        }
        for (int i = 0; i < texArr.count; i++) {
            [renderEncoder setFragmentTexture:texArr[i]
                                      atIndex:i];
//            [renderEncoder setFragmentTexture:texArr[i]
//                                      atIndex:EGTextureIndexBaseColor];
        }
        
//        if (pixelBuffer) {
//                CVPixelBufferRelease(pixelBuffer);
//        }
        // Draw the triangles.
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:self.numVertices];

        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable
        [commandBuffer presentDrawable:view.currentDrawable];


    }

    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
}


@end
