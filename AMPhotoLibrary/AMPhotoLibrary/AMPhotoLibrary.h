//
//  AMPhotoLibrary.h
//  AMPhotoLibrary
//
//  Created by ArcRain on 9/28/14.
//  Copyright (c) 2014 Sora Yang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>

#import "AMPhotoManager.h"

@interface AMPhotoLibrary : NSObject <AMPhotoManager>

+ (instancetype)sharedPhotoLibrary;

@end
