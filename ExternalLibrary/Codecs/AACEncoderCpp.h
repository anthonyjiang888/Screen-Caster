//
//  AACEncoderCpp.hpp
//  CameraTest
//
//  Created by alex on 09/03/2017.
//  Copyright © 2017 alex. All rights reserved.
//

#ifndef AACEncoderCpp_hpp
#define AACEncoderCpp_hpp

#include <stdio.h>
#include <AudioToolbox/AudioToolbox.h>
#include <CoreMedia/CoreMedia.h>
#include <mutex>
#include <functional>
#include <fstream>
#include <vector>

class AACEncoderCpp
{
public:
    
    AACEncoderCpp(int sampleRate, int channels, int bitrate, std::function<void(uint8_t*, size_t, std::array<uint8_t, 2>, CMTime)> compressedDataCallback);
    ~AACEncoderCpp();
    
    void putFrame(CMSampleBufferRef audioFrame);
    std::unique_ptr<std::ofstream> inputLog;
    std::unique_ptr<std::ofstream> outputLog;

private:
    static OSStatus ioProc(AudioConverterRef audioConverter, UInt32 *ioNumDataPackets, AudioBufferList* ioData, AudioStreamPacketDescription** ioPacketDesc, void* inUserData );
    uint8_t getSampleRateIndex(uint32_t sampleRate);
    std::array<uint8_t, 2> makeAsc();
    
    AudioStreamBasicDescription m_in, m_out;
    std::mutex              m_encoderLock;
    AudioConverterRef       m_audioEncoder;
    size_t                  m_bytesPerSample;
    uint32_t                m_outputPacketMaxSize;
    
    uint32_t m_bitrate;
    bool m_firstFrame;
    uint32_t m_sampleRate;
    uint32_t m_channels;
    uint32_t m_sampleIndex;
    
    uint8_t m_inputBuffer[1024*48];
    uint32_t m_inputBufferLength;
    
    std::function<void(uint8_t*, size_t, std::array<uint8_t, 2>, CMTime)> m_compressedDataCallback;
    std::vector<uint8_t> m_outputBuffer;
   
};

#endif /* AACEncoderCpp_hpp */
