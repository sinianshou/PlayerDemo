//
//  m3u8Test.m
//  PlayerDemo
//
//  Created by Easer Liu on 2020/1/10.
//  Copyright © 2020 EasyGoing. All rights reserved.
//


#import "m3u8Test.h"

#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
// 色彩转换、视频场景比例缩放
#include "libswscale/swscale.h"
#include "imgutils.h"

#import <CoreGraphics/CoreGraphics.h>

#define BYTE_ALIGN_2(_s_) (( _s_ + 1)/2 * 2)

@interface m3u8Test()
//{
//    AVFormatContext * formatContext;
//    AVPacket    packet;
//    AVPicture avPicture;
//    AVCodecContext *codecContext
//}
@property NSString* videoUrl;
@property UIImageView *imgView;
@property AVFormatContext * formatContext;
@property AVPacket    packet;
@property AVPicture avPicture;
@property AVCodecContext *codecContext;
// 流数据
@property AVStream *stream;
@property AVFrame *avFrame;
// 帧率
@property double fps;
// 视频流信息
@property int avStreamIndex;
// 视频画面的宽高
@property int frameImageWidth;
@property int frameImageHeight;
@property BOOL isPraseSuccess;
@property CVPixelBufferPoolRef pixelBufferPool;
@property dispatch_source_t timer;
@property CIContext * temporaryContext;
@end
@implementation m3u8Test
-(instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        self.videoUrl = @"https://hong.tianzhen-zuida.com/20200114/18504_3e975afd/index.m3u8";
        //        self.videoUrl =@"http://svpic-bj.oss-cn-beijing.aliyuncs.com/publictrailers/Task-129.mp4";
        self.videoUrl = [[NSBundle mainBundle] pathForResource:@"video" ofType:@"mp4"];
        self.backgroundColor = UIColor.redColor;
        _imgView = [[UIImageView alloc] initWithFrame:frame];
        [self addSubview:_imgView];
        [self play];
    }
    return self;
}
-(void)play{
    printf("play start");
    self.isPraseSuccess = [self prase];
    [self seekTime:0.0];
    [self decode];
}
- (void)seekTime:(double)seconds{
    AVRational timeBase = self.formatContext -> streams[self.avStreamIndex] ->time_base;
    
    int64_t timeFrame = (int64_t)( (double)timeBase.den / timeBase.num * seconds);
    
    // 跳转到0s帧处
    avformat_seek_file(_formatContext, _avStreamIndex, 0, timeFrame, timeFrame, AVSEEK_FLAG_FRAME);
    
    // 清空buffer状态
    avcodec_flush_buffers(_codecContext);
}
-(BOOL)prase{
    
    //解析
    avformat_network_init();
    AVCodec *codec;
    //初始化avformat上下文对象.
    self.formatContext = avformat_alloc_context();
    AVDictionary * opts = nil;
    av_dict_set(&opts, "timeout", "1000000", 0);
    int result = avformat_open_input(&_formatContext, [self.videoUrl UTF8String], NULL, &opts);
    
    BOOL isSucess = result < 0 ? NO : YES;
    if (!isSucess) {
        NSLog(@"Couldn't open file %@: %s", self.videoUrl, av_err2str(result));
        if (self.formatContext) {
            avformat_free_context(self.formatContext);
        }
        return false;
    }
    NSLog(@"open file Sucess %d %d", isSucess, result);
    //读取媒体文件的数据包以获取流信息
    result = avformat_find_stream_info(self.formatContext, NULL);
    if ( result < 0) {
        NSLog(@"avformat_find_stream_info failed %d",  result);
        avformat_close_input(&_formatContext);
        return false;
    }
    
    NSLog(@"avformat_find_stream_info Sucess %d",  result);
    
    // 查找音视频流、字幕流的stream_index， 找到流解码器
    //通过遍历format context对象可以从nb_streams数组中找到音频或视频流索引,以便后续使用.
    self.avStreamIndex = -1;
    BOOL isVideoStream = YES;
    self.avStreamIndex = av_find_best_stream(self.formatContext, (isVideoStream ? AVMEDIA_TYPE_VIDEO : AVMEDIA_TYPE_AUDIO), -1, -1, &codec, 0);
    
    if (self.avStreamIndex < 0) {
        //        log4cplus_error(kModuleName, "%s: Not find video stream",__func__);
        NSLog(@"avformat_find_stream_info failed %d",  self.avStreamIndex);
        return false;
    }
    NSLog(@"avformat_find_stream_info Sucess %d",  self.avStreamIndex);
    
    self.stream = self.formatContext->streams[self.avStreamIndex];
    codec =  avcodec_find_decoder(self.stream->codecpar->codec_id);
    if (codec == NULL)
    {
        NSLog(@"没有找到解码器");
        return false;
    }
    self.codecContext = avcodec_alloc_context3(codec);
    //复制解码器参数
    if(avcodec_parameters_to_context(self.codecContext, self.stream->codecpar)<0){
        NSLog(@"复制解码器参数失败");
        return  false;
    }
    
    if(avcodec_open2(_codecContext, codec, NULL)<0){
        printf("Could not open codec.\n");
        return false;
    }
    self.fps = 30;
    if (self.stream ->avg_frame_rate.den && self.stream ->avg_frame_rate.num)
    {
        self.fps = av_q2d(self.stream ->avg_frame_rate);
    }
    return true;
}

-(void)decode{
    [self decode3];
}
-(void)decode3{
    self.avFrame = av_frame_alloc();
    self.frameImageWidth = _codecContext ->width;
    self.frameImageHeight = _codecContext ->height;
    av_init_packet(&_packet);
    NSLog(@"current thread1 is %p %p", [NSThread currentThread], [NSThread mainThread]);
    
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    //开始时间
    dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC);
    //间隔时间
    uint64_t interval = 1/self.fps * NSEC_PER_SEC;
    dispatch_source_set_timer(self.timer, start, interval, 0);
    //设置回调
    dispatch_source_set_event_handler(self.timer, ^{
        
        NSLog(@"current thread2 is %p", [NSThread currentThread]);
        int decodeFinished = 0;
        
        while (!decodeFinished && av_read_frame(self->_formatContext, &(self->_packet)) >=0 ) // 读取每一帧数据
        {
            NSLog(@"每帧数据%d",self->_avStreamIndex);
            if (self->_packet.stream_index == self->_avStreamIndex) // 解码前的数据
            {
                // 解码数据
                // 解码一帧视频数据，存储到AVFrame中
                avcodec_decode_video2(self->_codecContext,self->_avFrame, &decodeFinished, &self->_packet);
                //                int re = avcodec_send_packet(self->_codecContext, &(self->_packet));
                //                NSLog(@"avcodec_send_packet %d",re);
                //                    int ret = avcodec_receive_frame(self->_codecContext, self->_avFrame);
                //                    NSLog(@"avcodec_receive_frame %d",ret);
            }
        }
        
        if (decodeFinished == 0 )
        {
            // 释放frame
            av_packet_unref(&self->_packet);
            // 释放YUV frame
            av_free(self->_avFrame);
            // 关闭解码器
            if (self->_codecContext) avcodec_close(self->_codecContext);
            // 关闭文件
            if (self->_formatContext) avformat_close_input(&self->_formatContext);
            avformat_network_deinit();
        }
        //        return  decodeFinished !=0;
        
        if (decodeFinished ==0)
        {
            //                    [timer invalidate];
            dispatch_source_cancel(self->_timer);
            self->_timer = nil;
        }
        if ( !self->_avFrame ->data[0])
        {
            return;
        }
        
        CVPixelBufferRef pixelBuffer = [self converCVPixelBufferRefFromAVFrame:self->_avFrame];
        UIImage*img = [self converUIImageFromCVPixelBufferRef:pixelBuffer];
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self.imgView setImage:img];
        }];
        //
    });
    //启动timer
    dispatch_resume(self.timer);
}
- (CVPixelBufferRef)converCVPixelBufferRefFromAVFrame:(AVFrame *)avframe {
    if (!avframe || !avframe->data[0]) {
        return NULL;
    }
    
    CVReturn theError;
    if (!self.pixelBufferPool){
        NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
        [attributes setObject:[NSNumber numberWithInt:avframe->width] forKey: (NSString*)kCVPixelBufferWidthKey];
        [attributes setObject:[NSNumber numberWithInt:avframe->height] forKey: (NSString*)kCVPixelBufferHeightKey];
        [attributes setObject:@(avframe->linesize[0]) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
        [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
        theError = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &self->_pixelBufferPool);
        if (theError != kCVReturnSuccess){
            NSLog(@"CVPixelBufferPoolCreate Failed");
        }
    }
    if (avframe->linesize[1] != avframe->linesize[2]) {
            return  NULL;
        }
    size_t srcPlaneSize = avframe->linesize[1]*avframe->height/2;
    size_t dstPlaneSize = srcPlaneSize *2;
    uint8_t *dstPlane = malloc(dstPlaneSize);
    
    // interleave Cb and Cr plane
    for(size_t i = 0; i<srcPlaneSize; i++){
        dstPlane[2*i  ]=avframe->data[1][i];
        dstPlane[2*i+1]=avframe->data[2][i];
    }
    CVPixelBufferRef pixelBuffer = NULL;
    theError = CVPixelBufferPoolCreatePixelBuffer(NULL, self.pixelBufferPool, &pixelBuffer);
    if(theError != kCVReturnSuccess){
        NSLog(@"CVPixelBufferPoolCreatePixelBuffer Failed");
    }
//    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
//
//                             @(avframe->linesize[0]), kCVPixelBufferBytesPerRowAlignmentKey,
//                             [NSNumber numberWithBool:YES], kCVPixelBufferOpenGLESCompatibilityKey,
//                             [NSDictionary dictionary], kCVPixelBufferIOSurfacePropertiesKey,
//                             nil];
//    int ret = CVPixelBufferCreate(kCFAllocatorDefault,
//                                  avframe->width,
//                                  avframe->height,
//                                  kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
//                                  (__bridge CFDictionaryRef)(options),
//                                  &pixelBuffer);
//    if(ret != kCVReturnSuccess)
//    {
//        NSLog(@"CVPixelBufferCreate Failed");
//        return NULL;
//    }
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    size_t bytePerRowY = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    size_t bytesPerRowUV = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    void* base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    memcpy(base, avframe->data[0], bytePerRowY * avframe->height);
    base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    memcpy(base, dstPlane, bytesPerRowUV * avframe->height/2);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    free(dstPlane);
    return pixelBuffer;
}

- (UIImage *)converUIImageFromCVPixelBufferRef:(CVPixelBufferRef)pixelBuffer {
    
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    if(!self.temporaryContext){
        self.temporaryContext = [CIContext contextWithOptions:nil];
    }
    CIContext * temporaryContext = self.temporaryContext;
    CGImageRef videoImage = [temporaryContext
                             createCGImage:ciImage
                             fromRect:CGRectMake(0, 0,
                                                 CVPixelBufferGetWidth(pixelBuffer),
                                                 CVPixelBufferGetHeight(pixelBuffer))];
    
    UIImage *uiImage = [UIImage imageWithCGImage:videoImage];
    
    CVPixelBufferRelease(pixelBuffer);
    CGImageRelease(videoImage);
    
    return uiImage;
    
}
-(void)decode2{
    //解码
    self.avFrame = av_frame_alloc();
    self.frameImageWidth = _codecContext ->width;
    self.frameImageHeight = _codecContext ->height;
    av_init_packet(&_packet);
    //    self.packet.data = 0;
    //    self.packet.size = 0;
    
    [NSTimer scheduledTimerWithTimeInterval:1/self.fps repeats:YES block:^(NSTimer * _Nonnull timer) {
        int decodeFinished = 0;
        
        while (!decodeFinished && av_read_frame(self->_formatContext, &(self->_packet)) >=0 ) // 读取每一帧数据
        {
            NSLog(@"每帧数据%d",self->_avStreamIndex);
            if (self->_packet.stream_index == self->_avStreamIndex) // 解码前的数据
            {
                // 解码数据
                // 解码一帧视频数据，存储到AVFrame中
                avcodec_decode_video2(self->_codecContext,self->_avFrame, &decodeFinished, &self->_packet);
                //                int re = avcodec_send_packet(self->_codecContext, &(self->_packet));
                //                NSLog(@"avcodec_send_packet %d",re);
                //                    int ret = avcodec_receive_frame(self->_codecContext, self->_avFrame);
                //                    NSLog(@"avcodec_receive_frame %d",ret);
            }
        }
        
        if (decodeFinished == 0 )
        {
            // 释放frame
            av_packet_unref(&self->_packet);
            // 释放YUV frame
            av_free(self->_avFrame);
            // 关闭解码器
            if (self->_codecContext) avcodec_close(self->_codecContext);
            // 关闭文件
            if (self->_formatContext) avformat_close_input(&self->_formatContext);
            avformat_network_deinit();
        }
        //        return  decodeFinished !=0;
        
        if (decodeFinished ==0)
        {
            [timer invalidate];
        }
        if ( !self->_avFrame ->data[0])
        {
            return;
        }
        
        
        
        avpicture_free(&self->_avPicture);
        avpicture_alloc(&self->_avPicture, AV_PIX_FMT_RGB24, self->_frameImageWidth, self->_frameImageHeight);
        struct SwsContext *imageCovertContext = sws_getContext(self->_avFrame->width, self->_avFrame ->height, AV_PIX_FMT_YUV420P, self->_frameImageWidth, self->_frameImageHeight, AV_PIX_FMT_RGB24, SWS_FAST_BILINEAR, NULL, NULL, NULL);
        if (imageCovertContext == nil)
        {
            return ;
        }
        // YUV数据转化为RGB数据
        sws_scale(imageCovertContext, self->_avFrame->data, self->_avFrame->linesize, 0, self->_avFrame->height, self->_avPicture.data, self->_avPicture.linesize);
        sws_freeContext(imageCovertContext);
        
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
        CFDataRef data = CFDataCreate(kCFAllocatorDefault,
                                      self->_avPicture.data[0],
                                      self->_avPicture.linesize[0] * self->_frameImageHeight);
        
        CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGImageRef cgImage = CGImageCreate(self->_frameImageWidth,
                                           self->_frameImageHeight,
                                           8,
                                           24,
                                           self->_avPicture.linesize[0],
                                           colorSpace,
                                           bitmapInfo,
                                           provider,
                                           NULL,
                                           NO,
                                           kCGRenderingIntentDefault);
        UIImage *image = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage);
        CGColorSpaceRelease(colorSpace);
        CGDataProviderRelease(provider);
        CFRelease(data);
        [self.imgView setImage:image];
    }];
}
-(void)decode1{
    //解码
    self.avFrame = av_frame_alloc();
    self.frameImageWidth = _codecContext ->width;
    self.frameImageHeight = _codecContext ->height;
    [NSTimer scheduledTimerWithTimeInterval:1/self.fps repeats:YES block:^(NSTimer * _Nonnull timer) {
        int decodeFinished = 0;
        
        while (!decodeFinished && av_read_frame(self->_formatContext, &(self->_packet)) >=0 ) // 读取每一帧数据
        {
            NSLog(@"每帧数据%d",self->_avStreamIndex);
            if (self->_packet.stream_index == self->_avStreamIndex) // 解码前的数据
            {
                // 解码数据
                // 解码一帧视频数据，存储到AVFrame中
                avcodec_decode_video2(self->_codecContext,self->_avFrame, &decodeFinished, &self->_packet);
            }
        }
        
        if (decodeFinished == 0 )
        {
            // 释放frame
            av_packet_unref(&self->_packet);
            // 释放YUV frame
            av_free(self->_avFrame);
            // 关闭解码器
            if (self->_codecContext) avcodec_close(self->_codecContext);
            // 关闭文件
            if (self->_formatContext) avformat_close_input(&self->_formatContext);
            avformat_network_deinit();
        }
        //        return  decodeFinished !=0;
        
        if (decodeFinished ==0)
        {
            [timer invalidate];
        }
        if ( !self->_avFrame ->data[0])
        {
            return;
        }
        
        avpicture_free(&self->_avPicture);
        avpicture_alloc(&self->_avPicture, AV_PIX_FMT_RGB24, self->_frameImageWidth, self->_frameImageHeight);
        
        struct SwsContext *imageCovertContext = sws_getContext(self->_avFrame->width, self->_avFrame ->height, AV_PIX_FMT_YUV420P, self->_frameImageWidth, self->_frameImageHeight, AV_PIX_FMT_RGB24, SWS_FAST_BILINEAR, NULL, NULL, NULL);
        if (imageCovertContext == nil)
        {
            return ;
        }
        // YUV数据转化为RGB数据
        sws_scale(imageCovertContext, self->_avFrame->data, self->_avFrame->linesize, 0, self->_avFrame->height, self->_avPicture.data, self->_avPicture.linesize);
        sws_freeContext(imageCovertContext);
        
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
        CFDataRef data = CFDataCreate(kCFAllocatorDefault,
                                      self->_avPicture.data[0],
                                      self->_avPicture.linesize[0] * self->_frameImageHeight);
        
        CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGImageRef cgImage = CGImageCreate(self->_frameImageWidth,
                                           self->_frameImageHeight,
                                           8,
                                           24,
                                           self->_avPicture.linesize[0],
                                           colorSpace,
                                           bitmapInfo,
                                           provider,
                                           NULL,
                                           NO,
                                           kCGRenderingIntentDefault);
        UIImage *image = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage);
        CGColorSpaceRelease(colorSpace);
        CGDataProviderRelease(provider);
        CFRelease(data);
        [self.imgView setImage:image];
    }];
}
@end
