//
//  testMTK.m
//  PlayerDemo
//
//  Created by Easer Liu on 2020/1/18.
//  Copyright © 2020 EasyGoing. All rights reserved.
//

#import "testMTK.h"

static testMTK *_oneShare;

@interface  testMTK()<MTKViewDelegate>

@property (nonatomic, assign) CVMetalTextureCacheRef textureCache;

// data
@property (nonatomic, assign) vector_uint2 viewportSize;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> texture;
@property (nonatomic, strong) id<MTLBuffer> vertices;
@property (nonatomic, strong) id<MTLBuffer> convertMatrix;
@property (nonatomic, assign) NSUInteger numVertices;

@end

@implementation testMTK

+(instancetype)shared{
    if (!_oneShare) {
        _oneShare = [[testMTK alloc] init];
        [_oneShare setup];
    }
    return _oneShare;
}
-(void)setup{
    self.fps = 60;
    [self setupPipeline];
    
}
-(void)setupPipeline{
    id<MTLLibrary> defaultLib = [self.mtkView.device newDefaultLibrary];
    id<MTLFunction> vertexFunc = [defaultLib newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentFunc = [defaultLib newFunctionWithName:@"fragmentFunc"];
    MTLRenderPipelineDescriptor * pipelStateDes = [[MTLRenderPipelineDescriptor alloc] init];
    pipelStateDes.label = @"simplePipeline";
    pipelStateDes.vertexFunction = vertexFunc;
    pipelStateDes.fragmentFunction = fragmentFunc;
    pipelStateDes.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat;
    NSError *err = nil;
    self.pipelineState = [self.mtkView.device newRenderPipelineStateWithDescriptor:pipelStateDes error:&err];
    self.commandQueue = [self.mtkView.device newCommandQueue];
}

-(MTKView *)mtkView{
    if (!_mtkView) {
        _mtkView = [[MTKView alloc] init];
        _mtkView.device = MTLCreateSystemDefaultDevice();
        if (!_mtkView.device) {
            NSLog(@"_mtkView.device is nil");
            return nil;
        }
        _mtkView.delegate = self;
        _viewportSize = (vector_uint2){_mtkView.drawableSize.width,_mtkView.drawableSize.height};
    }
    return _mtkView;
}
- (void)drawInMTKView:(nonnull MTKView *)view {
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    
    static const float vertexArrayData[] = {
            // 前 4 位 位置 x , y , z ,w
            0.577, -0.25, 0.0, 1.0,
            -0.577, -0.25, 0.0, 1.0,
            0.0,  0.5, 0.0, 1.0,
        };
        
    id<MTLBuffer> vertexBuffer = [self.mtkView.device newBufferWithBytes:vertexArrayData
                                             length:sizeof(vertexArrayData)
                                            options:0];
    
    UIImage * img = [UIImage imageNamed:@"timg.jpeg"];
    
    MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice:self.mtkView.device];
    NSError *err;
    id<MTLTexture> srcTex = [loader newTextureWithCGImage:img.CGImage options:nil error:&err];
    
    MTLRenderPassDescriptor * renderDes = [[MTLRenderPassDescriptor alloc] init];
    renderDes.colorAttachments[0].texture = dra
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    self.viewportSize = (vector_uint2){size.width, size.height};
}

@end
