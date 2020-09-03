//
//  AACEncoder.m
//  CameraTest
//
//  Created by alex on 12/03/2017.
//  Copyright © 2017 alex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AACEncoder.h"
#include "AACEncoderCpp.h"
#include <array>
#include <iostream>
#include <fstream>


@interface AACEncoder() {
    std::unique_ptr<AACEncoderCpp> m_impl;
}
@end

@implementation AACEncoder

-(id) initWithSampleRate:(int)sampleRate channels:(int)channels bitrate:(int)bitrate {
    self = [self init];
    if(self) {
        m_impl = std::unique_ptr<AACEncoderCpp>(new AACEncoderCpp(sampleRate, channels, bitrate, [self](uint8_t* compressedData, size_t compressedDataSize, std::array<uint8_t, 2> asc, CMTime timestamp){
            NSData* data = [NSData dataWithBytes:compressedData length:compressedDataSize];
            NSData* ascData = [NSData dataWithBytes:&asc[0] length:asc.size()];
            if(self.delegate) [self.delegate compressedAudioDataReceived:data asc:ascData pts:timestamp];
        }));
        std::string homePath = [NSHomeDirectory() UTF8String];
        m_impl->inputLog = std::unique_ptr<std::ofstream>( new std::ofstream(homePath + "/Documents/aac_input.txt"));
        m_impl->outputLog = std::unique_ptr<std::ofstream>( new std::ofstream(homePath + "/Documents/aac_log.txt"));
    }
    return self;
}

-(void) putCMSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if(m_impl) {
        m_impl->putFrame(sampleBuffer);
    }
}

@end
