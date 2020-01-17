//
//  m3u8Test.h
//  PlayerDemo
//
//  Created by Easer Liu on 2020/1/10.
//  Copyright © 2020 EasyGoing. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    XDXH264EncodeFormat,
    XDXH265EncodeFormat,
} XDXVideoEncodeFormat;

struct XDXParseVideoDataInfo {
    uint8_t                 *data;
    int                     dataSize;
    uint8_t                 *extraData;
    int                     extraDataSize;
    Float64                 pts;
    Float64                 time_base;
    int                     videoRotate;
    int                     fps;
    CMSampleTimingInfo      timingInfo;
    XDXVideoEncodeFormat    videoFormat;
};

struct XDXParseAudioDataInfo {
    uint8_t     *data;
    int         dataSize;
    int         channel;
    int         sampleRate;
    Float64     pts;
};

@interface m3u8Test : UIView
- (void)play;
@end

NS_ASSUME_NONNULL_END
