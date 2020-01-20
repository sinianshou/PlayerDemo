//
//  MtkMgr.h
//  PlayerDemo
//
//  Created by Easer Liu on 2020/1/19.
//  Copyright © 2020 EasyGoing. All rights reserved.
//

@import MetalKit;
#import <Foundation/Foundation.h>
@class m3u8Test;
NS_ASSUME_NONNULL_BEGIN

@interface MtkMgr : NSObject

@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) m3u8Test *m3u8T;

+ (nonnull instancetype)shared;
+ (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView;
- (void)displayImageFile: (NSURL *) url;
@end

NS_ASSUME_NONNULL_END
