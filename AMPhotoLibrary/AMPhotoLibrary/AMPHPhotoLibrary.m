//
//  AMPHPhotoLibrary.m
//  AMPhotoLibrary
//
//  Created by ArcRain on 9/28/14.
//  Copyright (c) 2014 Sora Yang. All rights reserved.
//

#import "AMPHPhotoLibrary.h"

@interface AMPHPhotoLibrary ()

@end

@implementation AMPHPhotoLibrary

static AMPHPhotoLibrary *s_sharedPhotoManager = nil;
+ (id<AMPhotoManager>)sharedPhotoManager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_sharedPhotoManager = [AMPHPhotoLibrary new];
    });
    return s_sharedPhotoManager;
}

- (void)createAlbum:(NSString *)title resultBlock:(AMPhotoManagerResultBlock)resultBlock
{
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle: title];
    } completionHandler:^(BOOL success, NSError *error) {
        if (resultBlock) {
            resultBlock(success, error);
        }
    }];
}

- (void)checkAlbum:(NSString *)title resultBlock:(AMPhotoManagerCheckBlock)resultBlock
{
    __block AMPhotoAlbum *foundAlbum = nil;
    [self enumerateAlbums:^(AMPhotoAlbum *album, BOOL *stop) {
        if ([album.title isEqualToString: title]) {
            foundAlbum = album;
            *stop = YES;
        }
    } resultBlock:^(BOOL success, NSError *error) {
        if (resultBlock) {
            resultBlock(foundAlbum, error);
        }
    }];
}

- (void)enumerateAlbums:(AMPhotoManagerAlbumEnumeratorBlock)enumeratorBlock resultBlock:(AMPhotoManagerResultBlock)resultBlock
{
    void (^notifyResult)(BOOL success, NSError *error) = ^(BOOL success, NSError *error) {
        if (resultBlock) {
            resultBlock(success, error);
        }
    };
    
    __block BOOL isStop = NO;
    do {
        PHFetchResult *cameraRollResult = [PHAsset fetchAssetsWithOptions: nil];
        PHAssetCollection *cameraRollCollection = [PHAssetCollection transientAssetCollectionWithAssetFetchResult: cameraRollResult title:NSLocalizedString(@"Camera Roll", nil)];
        if (enumeratorBlock) {
            AMPhotoAlbum *photoAlbum = [AMPhotoAlbum photoAlbumWithPHAssetCollection: cameraRollCollection];
            enumeratorBlock(photoAlbum, &isStop);
        }
        if (isStop) {
            break;
        }
        
        PHFetchResult *smartAlbumResult = [PHAssetCollection fetchAssetCollectionsWithType: PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
        [smartAlbumResult enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if (enumeratorBlock) {
                AMPhotoAlbum *photoAlbum = [AMPhotoAlbum photoAlbumWithPHAssetCollection: obj];
                enumeratorBlock(photoAlbum, stop);
                isStop = *stop;
            }
        }];
        if (isStop) {
            break;
        }
        
        PHFetchResult *albumResult = [PHAssetCollection fetchAssetCollectionsWithType: PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
        [albumResult enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if (enumeratorBlock) {
                AMPhotoAlbum *photoAlbum = [AMPhotoAlbum photoAlbumWithPHAssetCollection: obj];
                enumeratorBlock(photoAlbum, stop);
                isStop = *stop;
            }
        }];
    } while (false);
    notifyResult(YES, nil);
}

- (void)enumerateAssets:(AMPhotoManagerAssetEnumeratorBlock)enumeratorBlock inPhotoAlbum:(AMPhotoAlbum *)photoAlbum resultBlock:(AMPhotoManagerResultBlock)resultBlock
{
    void (^notifyResult)(BOOL success, NSError *error) = ^(BOOL success, NSError *error) {
        if (resultBlock) {
            resultBlock(success, error);
        }
    };
    
    if (nil == photoAlbum) {
        notifyResult(NO, nil);
        return;
    }
    
    __block BOOL isStop = NO;
    PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection: [photoAlbum asPHAssetCollection] options: nil];
    [fetchResult enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (enumeratorBlock) {
            AMPhotoAsset *photoAsset = [AMPhotoAsset photoAssetWithPHAsset: obj];
            enumeratorBlock(photoAsset, idx, stop);
            isStop = *stop;
        }
    }];
    notifyResult(YES, nil);
}

- (void)addAsset:(AMPhotoAsset *)asset toAlbum:(AMPhotoAlbum *)photoAlbum resultBlock:(AMPhotoManagerResultBlock)resultBlock
{
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetCollectionChangeRequest *collectionRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection: [photoAlbum asPHAssetCollection]];
        [collectionRequest addAssets: @[[asset asPHAsset]]];
    } completionHandler:^(BOOL success, NSError *error) {
        if (resultBlock) {
            resultBlock(success, error);
        }
    }];
}

- (void)writeImageToSavedPhotosAlbum:(UIImage *)image resultBlock:(AMPhotoManagerResultBlock)resultBlock
{
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage: image];
    } completionHandler:^(BOOL success, NSError *error) {
        if (resultBlock) {
            resultBlock(success, error);
        }
    }];
}

- (void)writeImage:(UIImage *)image toAlbum:(AMPhotoAlbum *)photoAlbum resultBlock:(AMPhotoManagerResultBlock)resultBlock
{
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetChangeRequest *assetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage: image];
        PHAssetCollectionChangeRequest *collectionRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection: [photoAlbum asPHAssetCollection]];
        [collectionRequest addAssets: @[assetRequest.placeholderForCreatedAsset]];
    } completionHandler:^(BOOL success, NSError *error) {
        if (resultBlock) {
            resultBlock(success, error);
        }
    }];
}

- (UIImage *)imageWithData:(NSData *)imageData metadata:(NSDictionary *)metadata
{
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    NSMutableDictionary *source_metadata = (NSMutableDictionary *)CFBridgingRelease(CGImageSourceCopyProperties(source, NULL));
    [source_metadata addEntriesFromDictionary: metadata];
    
    NSMutableData *dest_data = [NSMutableData data];
    CFStringRef UTI = CGImageSourceGetType(source);
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)dest_data, UTI, 1,NULL);
    CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef)source_metadata);
    CGImageDestinationFinalize(destination);
    CFRelease(source);
    CFRelease(destination);
    return [UIImage imageWithData: dest_data];
}

- (void)writeImageDataToSavedPhotosAlbum:(NSData *)imageData metadata:(NSDictionary *)metadata resultBlock:(AMPhotoManagerResultBlock)resultBlock
{
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        UIImage *image = [self imageWithData: imageData metadata:metadata];
        [PHAssetChangeRequest creationRequestForAssetFromImage: image];
    } completionHandler:^(BOOL success, NSError *error) {
        if (resultBlock) {
            resultBlock(success, error);
        }
    }];
}

- (void)writeImageData:(NSData *)imageData metadata:(NSDictionary *)metadata toAlbum:(AMPhotoAlbum *)photoAlbum resultBlock:(AMPhotoManagerResultBlock)resultBlock
{
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        UIImage *image = [self imageWithData: imageData metadata:metadata];
        PHAssetChangeRequest *assetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage: image];
        PHAssetCollectionChangeRequest *collectionRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection: [photoAlbum asPHAssetCollection]];
        [collectionRequest addAssets: @[assetRequest.placeholderForCreatedAsset]];
    } completionHandler:^(BOOL success, NSError *error) {
        if (resultBlock) {
            resultBlock(success, error);
        }
    }];
}

@end
