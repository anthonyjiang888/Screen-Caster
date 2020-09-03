//
//  AACEncoder.m
//  CameraTest
//
//  Created by alex on 12/03/2017.
//  Copyright © 2017 alex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FDKAACEncoder.h"
#include "FDKAACEncoderCpp.h"
#include <array>
#include <iostream>
#include <fstream>


@interface FDKAACEncoder() {
    std::unique_ptr<FDKAACEncoderCpp> m_impl;
}
@end

@implementation FDKAACEncoder

-(id) initWithSampleRate:(int)sampleRate channels:(int)channels bitrate:(int)bitrate {
    self = [self init];
    if(self) {
        m_impl = std::unique_ptr<FDKAACEncoderCpp>(new FDKAACEncoderCpp(sampleRate, channels, bitrate, [self](uint8_t* compressedData, size_t compressedDataSize, CMTime timestamp){
            //NSData* data = [NSData dataWithBytes:compressedData length:compressedDataSize];
            //if(self.delegate) [self.delegate compressedAudioDataReceived:data pts:timestamp];
            //if(m_impl->outputLog) *m_impl->outputLog << timestamp.value << ", size = " << compressedDataSize << std::endl;
            if(self.delegate) [self.delegate compressedAudioDataReceived:compressedData size:compressedDataSize pts:timestamp];
        }));
        std::string homePath = [NSHomeDirectory() UTF8String];
        //m_impl->inputLog = std::unique_ptr<std::ofstream>( new std::ofstream(homePath + "/Documents/aac_input.txt"));
        //m_impl->outputLog = std::unique_ptr<std::ofstream>( new std::ofstream(homePath + "/Documents/aac_log.txt"));
    }
    return self;
}

-(void) putCMSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if(m_impl) {
        m_impl->putFrame(sampleBuffer);
    }
}

-(void) putData:(uint8_t*)data size:(size_t)size pts:(CMTime)timestamp {
    if(m_impl) {
        m_impl->putData(data, size, timestamp);
    }
}

@end
