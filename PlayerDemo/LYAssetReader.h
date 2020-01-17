//
//  LYAssetReader.h
//  PlayerDemo
//
//  Created by Easer Liu on 2020/1/17.
//  Copyright © 2020 EasyGoing. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
NS_ASSUME_NONNULL_BEGIN


@interface LYAssetReader : NSObject

- (instancetype)initWithUrl:(NSURL *)url;

- (CMSampleBufferRef)readBuffer;

@end

NS_ASSUME_NONNULL_END
