//
//  InfiniteAudio.h
//  ChromecastDisplay
//
//  Created by alex on 07/06/2018.
//  Copyright © 2018 alex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FDKAACEncoder.h"

@interface InfiniteAudio : NSObject

-(id) initWithSampleRate:(int)sampleRate channels:(int)channels targetEncoder:(FDKAACEncoder*)encoder;
-(void) putCMSampleBuffer:(CMSampleBufferRef) sampleBuffer;
-(void) consumeToTime:(CMTime)time;
@property (nonatomic, weak) FDKAACEncoder* encoder;
@property (nonatomic) int sampleRate;
@property (nonatomic) int channels;

@end
