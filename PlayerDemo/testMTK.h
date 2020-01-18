//
//  testMTK.h
//  PlayerDemo
//
//  Created by Easer Liu on 2020/1/18.
//  Copyright © 2020 EasyGoing. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface testMTK : NSObject

@property (nonatomic, strong) MTKView* mtkView;
@property (nonatomic, assign) NSInteger fps;

+(instancetype)shared;

@end

NS_ASSUME_NONNULL_END
