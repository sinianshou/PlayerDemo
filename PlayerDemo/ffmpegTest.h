//
//  ffmpegTest.h
//  PlayerDemo
//
//  Created by Easer Liu on 2020/1/6.
//  Copyright © 2020 EasyGoing. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ffmpegTest : UIView

/**
 视频的url
 */
@property (nonatomic, copy) NSString *videoPath;


/**
 获取每一帧的图片
 */
@property(nonatomic,strong,readonly) UIImage *frameImage;

/**
 播放视频
 */
- (void)play;

/**
 暂停视频
 */
- (void)pause;

/**
 停止播放视频
 */
- (void)stop;

@end

NS_ASSUME_NONNULL_END
