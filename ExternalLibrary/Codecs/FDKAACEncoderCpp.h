//
//  FDKAACEncoderCpp.hpp
//  ChromecastDisplay
//
//  Created by alex on 01/06/2018.
//  Copyright © 2018 alex. All rights reserved.
//

#ifndef FDKAACEncoderCpp_hpp
#define FDKAACEncoderCpp_hpp

#include <stdio.h>
#include <AudioToolbox/AudioToolbox.h>
#include <CoreMedia/CoreMedia.h>
#include <mutex>
#include <functional>
#include <fstream>
#include <vector>

extern "C" {
#include "fdk-aac/aacenc_lib.h"
}

class FDKAACEncoderCpp
{
public:
    
    FDKAACEncoderCpp(int sampleRate, int channels, int bitrate, std::function<void(uint8_t*, size_t, CMTime)> compressedDataCallback);
    ~FDKAACEncoderCpp();
    
    void putFrame(CMSampleBufferRef audioFrame);
    void putData(uint8_t* data, size_t size, CMTime pts);
    std::unique_ptr<std::ofstream> inputLog;
    std::unique_ptr<std::ofstream> outputLog;
    
private:
    uint8_t getSampleRateIndex(uint32_t sampleRate);
    std::array<uint8_t, 2> makeAsc();
    
    
    uint32_t m_bitrate;
    bool m_firstFrame;
    uint32_t m_sampleRate;
    uint32_t m_channels;
    uint32_t m_sampleIndex;
    uint32_t m_bytesPerSample;
    uint32_t m_inputSamplesPerFrame;
    
    uint8_t m_inputBuffer[1024*256];
    uint8_t m_outputBuffer[1024*256];
    uint32_t m_inputBufferLength;
    
    HANDLE_AACENCODER hEncoder;
    CMTime previousInputPTS;
    
    std::function<void(uint8_t*, size_t, CMTime)> m_compressedDataCallback;
    
};
#endif /* FDKAACEncoderCpp_hpp */
