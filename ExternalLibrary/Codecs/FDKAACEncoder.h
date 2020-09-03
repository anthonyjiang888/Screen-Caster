//
//  AACEncoder.h
//  CameraTest
//
//  Created by alex on 12/03/2017.
//  Copyright © 2017 alex. All rights reserved.
//

#ifndef FDKAACEncoder_h
#define FDKAACEncoder_h

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>

@protocol FDKAACEncoderDelegate <NSObject>
-(void) compressedAudioDataReceived:(uint8_t*)data size:(size_t)size pts:(CMTime)pts;
@end

@interface FDKAACEncoder : NSObject
-(id) initWithSampleRate:(int)sampleRate channels:(int)channels bitrate:(int)bitrate;
-(void) putCMSampleBuffer:(CMSampleBufferRef) sampleBuffer;
-(void) putData:(uint8_t*)data size:(size_t)size pts:(CMTime)timestamp;
@property (nonatomic, weak) id<FDKAACEncoderDelegate> delegate;
@end


#endif /* FDKAACEncoder_h */
