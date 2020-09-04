//
//  HLSMuxer.h
//  MultiStreamer
//
//  Created by alex on 27/04/2018.
//  Copyright © 2018 alex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface HLSMuxer : NSObject

-(id) initWithTargetAddress:(NSString*)address;
-(void) putVideoSample:(CMSampleBufferRef)sampleBuffer;
-(void) putAudioSample:(uint8_t*)data size:(size_t)size pts:(CMTime)pts;

@end

