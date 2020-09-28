//
//  SampleHandlerHLS.m
//  BroadcastExtension
//
//  Created by alex on 12/04/2018.
//  Copyright © 2018 alex. All rights reserved.
//


#import "CustomHandlerHLS.h"
#import "MongooseDaemon.h"
#import "HLSMuxer.h"
#import "H264Encoder.h"
#import "FDKAACEncoder.h"
#import "InfiniteAudio.h"
#import <CoreImage/CoreImage.h>
#import <Accelerate/Accelerate.h>
#include <libkern/OSAtomic.h>


@interface PixelBuffer: NSObject
@property (nonatomic) CVPixelBufferRef pixels;
@property (nonatomic) CMSampleBufferRef sourceSample;
@end

@implementation PixelBuffer
@end

@interface CustomHandlerHLS ()<H264EncoderDelegate, FDKAACEncoderDelegate> {
    MongooseDaemon* mongoose;
    //LiveStreamer* streamer;
    HLSMuxer* streamer;
    H264Encoder* h264Encoder;
    FDKAACEncoder* aacEncoder;
    InfiniteAudio* infiniteAudio;
    
    dispatch_queue_t queue;
    
    int screenWidth;
    int screenHeight;
    NSTimeInterval lastTimeFrameEncoded;
    
    CMSimpleQueueRef sampleQueue;
    CMSampleBufferRef previousSample;
    CMSampleTimingInfo pInfo[16];
    
    CMTime previousAudioSampleTime;
    CMTime previousVideoSampleTime;
}
@end

@implementation CustomHandlerHLS

- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *,NSObject *> *)setupInfo {
    mongoose = [[MongooseDaemon alloc] init];
    [mongoose startMongooseDaemon:@"8080"];
    
    queue = dispatch_queue_create("encoderQueue", NULL);
    //dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    
    
    CMSimpleQueueCreate(kCFAllocatorDefault, 8, &sampleQueue);
    
    h264Encoder = nil;
    previousSample = nil;
    aacEncoder = nil;
    infiniteAudio = nil;
    
    previousAudioSampleTime.value = 0;
    previousVideoSampleTime.value = 0;
    previousVideoSampleTime.timescale = 1000000000;
    previousAudioSampleTime.timescale = 1000000000;
    
    streamer = [[HLSMuxer alloc] initWithTargetAddress:@""];
    lastTimeFrameEncoded = [[NSDate date] timeIntervalSince1970];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),queue, ^{
        [self processQueue];
    });
}

- (void)broadcastPaused {
    // User has requested to pause the broadcast. Samples will stop being delivered.
}

- (void)broadcastResumed {
    // User has requested to resume the broadcast. Samples delivery will resume.
}

- (void)broadcastFinished {
    // User has requested to finish the broadcast.
    [mongoose stopMongooseDaemon];
    if(h264Encoder != nil) {
        [h264Encoder close];
        h264Encoder = nil;
    }
    aacEncoder = nil;
}



- (CVPixelBufferRef) RotateBuffer:(CVPixelBufferRef)imageBuffer withConstant:(uint8_t)rotationConstant
{
    
    vImage_Error err = kvImageNoError;
    
    
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    
    assert(CVPixelBufferGetPixelFormatType(imageBuffer) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange);
    assert(CVPixelBufferGetPlaneCount(imageBuffer) == 2);
    //NSLog(@"YBuffer %ld %ld %ld",   CVPixelBufferGetWidthOfPlane(imageBuffer, 0), CVPixelBufferGetHeightOfPlane(imageBuffer, 0),
    //      CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0)); // BytesPerRow = width + 32
    //dumpData(@"Base=", CVPixelBufferGetBaseAddress(imageBuffer), width);
    //dumpData(@"Plane0=", CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0), width);
    
    
    //CVPixelBufferLockBaseAddress(_scaledPixels, 0);
    
    
    
    
    
    
    CVPixelBufferRef rotatedBuffer = NULL;
    //if(kCVReturnSuccess != CVPixelBufferPoolCreatePixelBuffer(NULL, _pool, &rotatedBuffer)) return nil;
    //    if(kCVReturnSuccess != CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(NULL,
    //                                                        _pool,
    //                                                        (__bridge CFDictionaryRef)@{
    //                                                                                    // Opt to fail buffer creation in case of slow buffer consumption
    //                                                                                    // rather than to exhaust all memory.
    //                                                                                    (__bridge id)kCVPixelBufferPoolAllocationThresholdKey: @8
    //                                                                                    }, // aux attributes
    //                                                        &rotatedBuffer
    //                                                                               )) return nil;
    //    //CVReturn ret = CVPixelBufferCreate(kCFAllocatorDefault, screenWidth, screenHeight, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, NULL, &rotatedBuffer);
    
    
    
    CVPixelBufferLockBaseAddress(rotatedBuffer, 0);
    
    // rotate Y plane
    vImage_Buffer originalYBuffer = { CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0), CVPixelBufferGetHeightOfPlane(imageBuffer, 0),
        CVPixelBufferGetWidthOfPlane(imageBuffer, 0), CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0) };
    //    vImage_Buffer scaledYBuffer = { CVPixelBufferGetBaseAddressOfPlane(_scaledPixels, 0), CVPixelBufferGetHeightOfPlane(_scaledPixels, 0),
    //        CVPixelBufferGetWidthOfPlane(rotatedBuffer, 0), CVPixelBufferGetBytesPerRowOfPlane(rotatedBuffer, 0) };
    vImage_Buffer rotatedYBuffer = { CVPixelBufferGetBaseAddressOfPlane(rotatedBuffer, 0), CVPixelBufferGetHeightOfPlane(rotatedBuffer, 0),
        CVPixelBufferGetWidthOfPlane(rotatedBuffer, 0), CVPixelBufferGetBytesPerRowOfPlane(rotatedBuffer, 0) };
    err = vImageRotate90_Planar8(&originalYBuffer, &rotatedYBuffer, 1, 0.0, kvImageNoFlags);
    //err = vImageScale_Planar8(&originalYBuffer, &scaledYBuffer, NULL, kvImageNoFlags);
    //err = vImageRotate90_Planar8(&scaledYBuffer, &rotatedYBuffer, 1, 0.0, kvImageNoFlags);
    //NSLog(@"rotatedYBuffer rotated %ld %ld %ld p=%p", rotatedYBuffer.width, rotatedYBuffer.height, rotatedYBuffer.rowBytes, rotatedYBuffer.data);
    //NSLog(@"RotateY err=%ld", err);
    //dumpData(@"Rotated Plane0=", rotatedYBuffer.data, outWidth);
    
    // rotate UV plane
    vImage_Buffer originalUVBuffer = { CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1), CVPixelBufferGetHeightOfPlane(imageBuffer, 1),
        CVPixelBufferGetWidthOfPlane(imageBuffer, 1), CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1) };
    //    vImage_Buffer scaledUVBuffer = { CVPixelBufferGetBaseAddressOfPlane(_scaledPixels, 1), CVPixelBufferGetHeightOfPlane(_scaledPixels, 1),
    //        CVPixelBufferGetWidthOfPlane(rotatedBuffer, 1), CVPixelBufferGetBytesPerRowOfPlane(rotatedBuffer, 1) };
    vImage_Buffer rotatedUVBuffer = { CVPixelBufferGetBaseAddressOfPlane(rotatedBuffer, 1), CVPixelBufferGetHeightOfPlane(rotatedBuffer, 1),
        CVPixelBufferGetWidthOfPlane(rotatedBuffer, 1), CVPixelBufferGetBytesPerRowOfPlane(rotatedBuffer, 1) };
    err = vImageRotate90_Planar16U(&originalUVBuffer, &rotatedUVBuffer, 1, 0.0, kvImageNoFlags);
    //err = vImageScale_CbCr8(&originalUVBuffer, &scaledUVBuffer, NULL, kvImageNoFlags);
    //err = vImageRotate90_Planar16U(&scaledUVBuffer, &rotatedUVBuffer, 1, 0.0, kvImageNoFlags);
    //NSLog(@"RotateUV err=%ld", err);
    //dumpData(@"Rotated Plane1=", rotatedUVBuffer.data, outWidth);
    
    CVPixelBufferUnlockBaseAddress(rotatedBuffer, 0);
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    //    CVPixelBufferUnlockBaseAddress(_scaledPixels, 0);
    
    return rotatedBuffer;
}

-(void)processQueue {
    
    @try
    {
        if(CMSimpleQueueGetCount(sampleQueue) == 0 && previousSample != nil)
        {
            if(fabs([[NSDate date] timeIntervalSince1970] - lastTimeFrameEncoded) > 0.1 && previousSample != nil) {
                CMTime timeStamp = CMSampleBufferGetPresentationTimeStamp(previousSample);
                timeStamp.value += ([[NSDate date] timeIntervalSince1970] - lastTimeFrameEncoded)*0.999*timeStamp.timescale;
                CMItemCount count;
                if(noErr == CMSampleBufferGetSampleTimingInfoArray(previousSample, 16, pInfo, &count))
                {
                    for (CMItemCount i = 0; i < count; i++)
                    {
                        pInfo[i].decodeTimeStamp = kCMTimeInvalid;
                        pInfo[i].presentationTimeStamp = timeStamp;
                        
                    }
                    CMSampleBufferRef sout;
                    if(noErr == CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, previousSample, count, pInfo, &sout))
                    {
                        if(noErr != CMSimpleQueueEnqueue(sampleQueue, sout))
                        {
                            CFRelease(sout);
                        }
                    }
                }
            }
        }
        
        CMSampleBufferRef sampleBuffer;
        while((sampleBuffer = (CMSampleBufferRef)CMSimpleQueueDequeue(sampleQueue)) != nil)
        {
            
            CMTime timeStamp;
            timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            
            if(previousSample != nil) {
                CMTime previousTimeStamp = CMSampleBufferGetPresentationTimeStamp(previousSample);
                if(previousTimeStamp.value > timeStamp.value) {
                    CFRelease(sampleBuffer);
                    continue;
                }
            }
            
            CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            if(imageBuffer == nil) continue;
            size_t width = CVPixelBufferGetWidth(imageBuffer);
            size_t height = CVPixelBufferGetHeight(imageBuffer);
            
            screenWidth = (int)width;
            screenHeight = (int)height;
            
            if(h264Encoder == nil) {
                
                int encoderWidth = screenWidth * 1280 / screenHeight;// 1280;
                int encoderHeight = 1280;//(screenHeight * 1280/ screenWidth);
                if(fabs(16.0/9.0 - (double)screenHeight / (double)screenWidth) < 0.1)
                {
                    encoderWidth = 720;
                    encoderHeight = 1280;
                } else if(fabs(4.0/3.0 - (double)screenHeight / (double)screenWidth) < 0.1)
                {
                    encoderWidth = 960;
                    encoderHeight = 1280;
                }
                
                
                h264Encoder = [[H264Encoder alloc] initWithWidth:encoderWidth height:encoderHeight bitrate:2000*1000 framerate:30];
                h264Encoder.delegate = self;
            }
            [h264Encoder putCVPixelBuffer:imageBuffer withTimestamp:timeStamp];
            CMTime audioTimestamp = timeStamp;
            audioTimestamp.value -= timeStamp.timescale * 0.7;
            if(infiniteAudio != nil) [infiniteAudio consumeToTime:audioTimestamp];
            previousVideoSampleTime = timeStamp;
            if(previousSample != nil) CFRelease(previousSample);
            previousSample = sampleBuffer;
            lastTimeFrameEncoded = [[NSDate date] timeIntervalSince1970];
        }
        
    }
    @catch(NSException *exception)
    {
        
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),queue, ^{
        [self processQueue];
    });
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)sampleBufferType {
    //NSLog(@"sample received");
    switch (sampleBufferType) {
        case RPSampleBufferTypeVideo:
            // Handle video sample buffer
        {
            if(CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_DroppedFrameReason, NULL)) break;;
            if(CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_DroppedFrameReasonInfo, NULL)) break;;
            if(CMGetAttachment(sampleBuffer, kCMSampleBufferDroppedFrameReason_Discontinuity, NULL)) break;;
            if(CMGetAttachment(sampleBuffer, kCMSampleBufferDroppedFrameReason_OutOfBuffers, NULL)) break;;
            if(CMGetAttachment(sampleBuffer, kCMSampleBufferDroppedFrameReason_FrameWasLate, NULL)) break;;
            if(!CMSampleBufferDataIsReady(sampleBuffer) || !CMSampleBufferIsValid(sampleBuffer)) break;
            
            
            CFRetain(sampleBuffer);
            
            //            dispatch_async(queue, ^{
            @try
            {
                if(previousSample != nil)
                {
                    CMTime timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                    CMTime previousTimeStamp = CMSampleBufferGetPresentationTimeStamp(previousSample);
                    if(previousTimeStamp.value > timeStamp.value) {
                        CFRelease(sampleBuffer);
                        sampleBuffer = nil;
                    }
                }
                
                if(sampleBuffer != nil && noErr != CMSimpleQueueEnqueue(sampleQueue, sampleBuffer))
                {
                    CFRelease(sampleBuffer);
                    sampleBuffer = nil;
                }
                else sampleBuffer = nil;
            }
            @catch(NSException *exception)
            {
                
            }
            @finally
            {
                if(sampleBuffer != nil) {
                    CFRelease(sampleBuffer);
                    sampleBuffer = nil;
                }
            }
            //});
        }
            break;
        case RPSampleBufferTypeAudioApp:
        {
            if(CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_DroppedFrameReason, NULL)) break;;
            if(CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_DroppedFrameReasonInfo, NULL)) break;;
            if(CMGetAttachment(sampleBuffer, kCMSampleBufferDroppedFrameReason_Discontinuity, NULL)) break;;
            if(CMGetAttachment(sampleBuffer, kCMSampleBufferDroppedFrameReason_OutOfBuffers, NULL)) break;;
            if(CMGetAttachment(sampleBuffer, kCMSampleBufferDroppedFrameReason_FrameWasLate, NULL)) break;;
            if(!CMSampleBufferDataIsReady(sampleBuffer) || !CMSampleBufferIsValid(sampleBuffer)) break;

            CMTime timeStamp;
            timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            if(timeStamp.value < previousAudioSampleTime.value || CMTimeGetSeconds(timeStamp) < CMTimeGetSeconds(previousVideoSampleTime) - 1) break;

//            if(aacEncoder == nil) {
//                CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
//                const AudioStreamBasicDescription* const asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
//                aacEncoder = [[FDKAACEncoder alloc] initWithSampleRate:asbd->mSampleRate channels:asbd->mChannelsPerFrame bitrate:64000];
//                aacEncoder.delegate = self;
//
//            }
//            [aacEncoder putCMSampleBuffer:sampleBuffer];

            __block CMSampleBufferRef sampleCopy = sampleBuffer;
            CFRetain(sampleCopy);

            dispatch_async(queue, ^{
                @try
                {
                    if(aacEncoder == nil) {
                        CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleCopy);
                        const AudioStreamBasicDescription* const asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
                        aacEncoder = [[FDKAACEncoder alloc] initWithSampleRate:asbd->mSampleRate channels:asbd->mChannelsPerFrame bitrate:64000];
                        aacEncoder.delegate = self;
                        infiniteAudio = [[InfiniteAudio alloc] initWithSampleRate:asbd->mSampleRate channels:asbd->mChannelsPerFrame targetEncoder:aacEncoder];
                    }
                    [infiniteAudio putCMSampleBuffer:sampleCopy];
                    //[aacEncoder putCMSampleBuffer:sampleCopy];
                    
                }
                @catch(NSException *exception)
                {
                    
                }
                @finally
                {
                    if(sampleCopy != nil) {
                        CFRelease(sampleCopy);
                        sampleCopy = nil;
                    }
                }
            });
        }
            // Handle audio sample buffer for app audio
            break;
        case RPSampleBufferTypeAudioMic:
            // Handle audio sample buffer for mic audio
            break;
            
        default:
            break;
    }
    //CMSampleBufferInvalidate(sampleBuffer);
}

- (void)compressedVideoDataReceived:(CMSampleBufferRef)sampleBuffer {
    @try
    {
        CFRetain(sampleBuffer);
        dispatch_async(queue, ^{
            [streamer putVideoSample:sampleBuffer];
            CFRelease(sampleBuffer);
        });
    }
    @catch(NSException* e)
    {
    }
}

-(void) compressedAudioDataReceived:(uint8_t*)data size:(size_t)size pts:(CMTime)pts {
    //dispatch_async(queue, ^{
        [streamer putAudioSample:data size:size pts:pts];
    //});
}


@end
