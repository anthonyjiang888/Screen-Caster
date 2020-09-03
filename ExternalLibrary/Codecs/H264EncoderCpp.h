//
//  H264Encoder.hpp
//  CameraTest
//
//  Created by alex on 05/03/2017.
//  Copyright © 2017 alex. All rights reserved.
//

#ifndef H264Encoder_hpp
#define H264Encoder_hpp

#include <stdio.h>
#include <CoreVideo/CoreVideo.h>
#include <VideoToolbox/VideoToolbox.h>
#include <dispatch/dispatch.h>

#include <mutex>
#include <functional>

class H264EncoderCpp
{
public:
    H264EncoderCpp(int width, int height, int bitrate, int frameRate, std::function<void(CMSampleBufferRef)> compressedDataCallback);
    ~H264EncoderCpp();
    
    CVPixelBufferPoolRef pixelBufferPool();
    
    void putFrame(CVPixelBufferRef pixelBuffer, CMTime timestamp);
    
    void signalCompressedData(CMSampleBufferRef compressedData);
    void closeCompressionSession();
    int getQueueLength();
    
private:
    void initCompressionSession();
    
    std::mutex m_encoderLock;
    VTCompressionSessionRef m_compressionSession;
    int m_width;
    int m_height;
    int m_bitrate;
    int m_frameRate;
    std::function<void(CMSampleBufferRef)> m_compressedDataCallback;
};

#endif /* H264Encoder_hpp */
