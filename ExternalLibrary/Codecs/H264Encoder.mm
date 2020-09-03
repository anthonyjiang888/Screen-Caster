//
//  H264Encoder.m
//  CameraTest
//
//  Created by alex on 05/03/2017.
//  Copyright © 2017 alex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "H264Encoder.h"
#include "H264EncoderCpp.h"
#include <fstream>


@interface H264Encoder() {
    std::unique_ptr<H264EncoderCpp> m_impl;
    std::unique_ptr<std::ofstream> inputLog;
    //std::unique_ptr<std::ofstream> outputLog;
    CMTime previousInputTimestamp;
    //CMTime previousOutputTimestamp;
}
@end

@implementation H264Encoder

-(id) initWithWidth:(int)width height:(int)height bitrate:(int)bitrate framerate:(int)framerate {
    self = [self init];
    if(self) {
        m_impl = std::unique_ptr<H264EncoderCpp>(new H264EncoderCpp(width, height, bitrate, framerate, [self](CMSampleBufferRef sampleBuffer){
            //CMBlockBufferRef block = CMSampleBufferGetDataBuffer(sampleBuffer);
            //    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
            //    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            //    CMTime dts = CMSampleBufferGetDecodeTimeStamp(sampleBuffer);
            //char* bufferData;
            //size_t size;
            //CMBlockBufferGetDataPointer(block, 0, NULL, &size, &bufferData);
            //NSLog(@"compressed data at objective C level, %zu bytes", size);
            if(self.delegate != nil) [self.delegate compressedVideoDataReceived:sampleBuffer];
            CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
//            if(outputLog != nullptr) {
//                //*output << "test" << std::endl;
//                *outputLog << "OUT: " << uint64_t(pts.value) << ", diff = " << pts.value - previousOutputTimestamp.value << std::endl;
//                previousOutputTimestamp = pts;
//            }
        }));
        std::string homePath = [NSHomeDirectory() UTF8String];
       // inputLog = std::unique_ptr<std::ofstream>( new std::ofstream(homePath + "/Documents/input.txt"));
        //*inputLog << "hi" << std::endl;
        //outputLog = std::unique_ptr<std::ofstream>( new std::ofstream(homePath + "/Documents/log.txt"));
        //*outputLog << "hi" << std::endl;
    }
    return self;
}

-(void) putCVPixelBuffer:(CVPixelBufferRef)pixelBuffer withTimestamp:(CMTime)timestamp {
    if(m_impl) {
        if(inputLog != nullptr) {
            //*output << "test" << std::endl;
            *inputLog << "IN: " << *(int*)&pixelBuffer << ", time = " << uint64_t(timestamp.value) << ", diff = " << timestamp.value - previousInputTimestamp.value << ", queue = " << m_impl->getQueueLength() << std::endl;
            previousInputTimestamp = timestamp;
        }
        m_impl->putFrame(pixelBuffer, timestamp);
    }
}

-(void)close {
    if(m_impl) {
        m_impl->closeCompressionSession();
    }
}

-(CVPixelBufferPoolRef) getPixelBufferPool {
    if(m_impl) {
        return m_impl->pixelBufferPool();
    }
    return nil;
}
@end
