//
//  AACDecoder.h
//  LiveStreamer
//
//  Created by alex on 02/08/2017.
//  Copyright © 2017 alex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>

@protocol AACDecoderDelegate <NSObject>
-(void) decompressedAudioDataReceived:(NSData*) data pts:(CMTime)pts;
@end


@interface AACDecoder : NSObject

@property (nonatomic) AudioConverterRef audioConverter;
- (void)setupAudioConverter;
- (void)decodeAudioFrame:(NSData *)frame withPts:(CMTime)pts;
@property (nonatomic, weak) id<AACDecoderDelegate> delegate;
@end
