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

// Header shared between C code here, which executes Metal API commands, and .metal files, which
//   uses these types as inputs to the shaders
#import "AAPLShaderTypes.h"
static MtkMgr *_oneSharedMM;

@interface MtkMgr ()<MTKViewDelegate>{
    MTKView *_mtkView;
}

@property (nonatomic, strong) NSURL* fileUrl;
@property (nonatomic, assign) MediaType mediaType;

// data
@property (nonatomic, assign) vector_uint2 viewportSize;
@property (nonatomic, strong) id<MTLTexture> texture;
@property (nonatomic, strong) id<MTLBuffer> vertices;
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
    NSAssert(_mtkView.device, @"Metal is not supported on this device");


    // Set up a simple MTLBuffer with vertices which include texture coordinates
    static const AAPLVertex quadVertices[] =
    {
        // Pixel positions, Texture coordinates
        { {  250,  -250 },  { 1.f, 1.f } },
        { { -250,  -250 },  { 0.f, 1.f } },
        { { -250,   250 },  { 0.f, 0.f } },

        { {  250,  -250 },  { 1.f, 1.f } },
        { { -250,   250 },  { 0.f, 0.f } },
        { {  250,   250 },  { 1.f, 0.f } },
    };

    // Create a vertex buffer, and initialize it with the quadVertices array
    self.vertices = [_mtkView.device newBufferWithBytes:quadVertices
                                     length:sizeof(quadVertices)
                                    options:MTLResourceStorageModeShared];

    // Calculate the number of vertices by dividing the byte length by the size of each vertex
    self.numVertices = sizeof(quadVertices) / sizeof(AAPLVertex);

    /// Create the render pipeline.

    // Load the shaders from the default library
    id<MTLLibrary> defaultLibrary = [_mtkView.device newDefaultLibrary];
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"samplingShader"];

    // Set up a descriptor for creating a pipeline state object
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"Texturing Pipeline";
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = _mtkView.colorPixelFormat;

    NSError *error = NULL;
    _pipelineState = [_mtkView.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                             error:&error];

    NSAssert(_pipelineState, @"Failed to created pipeline state, error %@", error);

    _commandQueue = [_mtkView.device newCommandQueue];
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
    NSData * data = [NSData dataWithContentsOfURL:url];
    UIImage * image = [UIImage imageWithData:data];
    
    self.mtkView.drawableSize = image.size;
    NSLog(@"size is %f, %f, %f, %f,", self.mtkView.drawableSize.height, self.mtkView.drawableSize.width, image.size.height,image.size.width);
    NSError *err = nil;
    MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:self.mtkView.device];
    id<MTLTexture> texture = [textureLoader newTextureWithCGImage:image.CGImage options:@{MTKTextureLoaderOptionSRGB: @NO} error:&err];
    
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
                                          kCVPixelFormatType_32BGRA,
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
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        // Set the region of the drawable to draw into.
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, self.viewportSize.x, self.viewportSize.y, -1.0, 1.0 }];

        [renderEncoder setRenderPipelineState:self.pipelineState];

        [renderEncoder setVertexBuffer:self.vertices
                                offset:0
                              atIndex:AAPLVertexInputIndexVertices];

        [renderEncoder setVertexBytes:&_viewportSize
                               length:sizeof(_viewportSize)
                              atIndex:AAPLVertexInputIndexViewportSize];

        // Set the texture object.  The AAPLTextureIndexBaseColor enum value corresponds
        ///  to the 'colorMap' argument in the 'samplingShader' function because its
        //   texture attribute qualifier also uses AAPLTextureIndexBaseColor for its index.
        id<MTLTexture> texture = nil;
        switch (self.mediaType) {
            case MediaTypeImage:
                texture = self.texture;
                break;
            case MediaTypeNone:
                break;
            case MediaTypeVideo:
            case MediaTypeAudio:
                break;
        }
        [renderEncoder setFragmentTexture:texture
                                  atIndex:AAPLTextureIndexBaseColor];

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
