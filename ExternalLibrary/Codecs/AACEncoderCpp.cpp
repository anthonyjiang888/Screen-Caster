//
//  AACEncoderCpp.cpp
//  CameraTest
//
//  Created by alex on 09/03/2017.
//  Copyright © 2017 alex. All rights reserved.
//

#include "AACEncoderCpp.h"
#include <inttypes.h>
#include <iostream>
#include <array>

struct UserData {
    uint8_t* data;
    int size;
    int packetSize;
    AudioStreamPacketDescription* pd;
} ;

static const int kSamplesPerFrame = 1024;

AACEncoderCpp::AACEncoderCpp(int sampleRate, int channels, int bitrate, std::function<void(uint8_t*, size_t, std::array<uint8_t, 2>, CMTime)> compressedDataCallback):
    m_sampleRate(sampleRate),
    m_channels(channels),
    m_bitrate(bitrate),
    m_in({0}),
    m_out({0}),
    m_inputBufferLength(0),
    m_outputBuffer(65536),
    m_compressedDataCallback(compressedDataCallback)
{
    m_in.mSampleRate = sampleRate;
    m_in.mChannelsPerFrame = channels;
    m_in.mBitsPerChannel = 16;
    m_in.mFormatFlags =  kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    m_in.mFormatID = kAudioFormatLinearPCM;
    m_in.mFramesPerPacket = 1;
    m_in.mBytesPerFrame = m_in.mBitsPerChannel * m_in.mChannelsPerFrame / 8;
    m_in.mBytesPerPacket = m_in.mFramesPerPacket * m_in.mBytesPerFrame;
    
    m_out.mFormatID = kAudioFormatMPEG4AAC;
    m_out.mFormatFlags = kMPEG4Object_AAC_LC;
    m_out.mFramesPerPacket = kSamplesPerFrame;
    m_out.mSampleRate = sampleRate;
    m_out.mChannelsPerFrame = channels;
    
    AudioClassDescription codecsRequest[2] = {
        {
            kAudioEncoderComponentType,
            kAudioFormatMPEG4AAC,
            kAppleSoftwareAudioCodecManufacturer
        },
        {
            kAudioEncoderComponentType,
            kAudioFormatMPEG4AAC,
            kAppleHardwareAudioCodecManufacturer
        }
    };
    
    OSStatus result = AudioConverterNewSpecific(&m_in, &m_out, 2, codecsRequest, &m_audioEncoder);
    if(result == noErr) {
        result = AudioConverterSetProperty(m_audioEncoder, kAudioConverterEncodeBitRate, sizeof(m_bitrate), &m_bitrate);
        if(result == noErr) {
            UInt32 fieldSize = uint32_t(sizeof(m_outputPacketMaxSize));
            result = AudioConverterGetProperty(m_audioEncoder,
                                               kAudioConverterPropertyMaximumOutputPacketSize,
                                               &fieldSize,
                                               &m_outputPacketMaxSize);
            if(result != noErr) {
                std::cout << "audioConverter get max output packet size failed" << std::endl;
            }
            
        } else {
            std::cout << "audioConverter set bitrate failed" << std::endl;
        }
    } else {
        std::cout << "audioConverterNewSpecific failed" << std::endl;
    }
    
    if(result == noErr) {
        m_bytesPerSample = 2 * m_channels;
    } else {
        std::cout << "AAC encoder initialization failed: " << std::hex << (int)result << std::dec << std::endl;
    }
}

AACEncoderCpp::~AACEncoderCpp() {
    AudioConverterDispose(m_audioEncoder);
}

uint8_t AACEncoderCpp::getSampleRateIndex(uint32_t sampleRate) {
    uint8_t sampleRateIndex = 0;
    switch(sampleRate) {
        case 96000:
            sampleRateIndex = 0;
            break;
        case 88200:
            sampleRateIndex = 1;
            break;
        case 64000:
            sampleRateIndex = 2;
            break;
        case 48000:
            sampleRateIndex = 3;
            break;
        case 44100:
            sampleRateIndex = 4;
            break;
        case 32000:
            sampleRateIndex = 5;
            break;
        case 24000:
            sampleRateIndex = 6;
            break;
        case 22050:
            sampleRateIndex = 7;
            break;
        case 16000:
            sampleRateIndex = 8;
            break;
        case 12000:
            sampleRateIndex = 9;
            break;
        case 11025:
            sampleRateIndex = 10;
            break;
        case 8000:
            sampleRateIndex = 11;
            break;
        case 7350:
            sampleRateIndex = 12;
            break;
        default:
            sampleRateIndex = 15;
    }
    return sampleRateIndex;
}

OSStatus AACEncoderCpp::ioProc(AudioConverterRef audioConverter, UInt32 *ioNumDataPackets, AudioBufferList* ioData, AudioStreamPacketDescription** ioPacketDesc, void* inUserData ) {
    UserData* ud = static_cast<UserData*>(inUserData);
    
    UInt32 maxPackets = ud->size / ud->packetSize;
    
    *ioNumDataPackets = std::min(maxPackets, *ioNumDataPackets);
    
    ioData->mBuffers[0].mData = ud->data;
    ioData->mBuffers[0].mDataByteSize = ud->size;
    ioData->mBuffers[0].mNumberChannels = 1;
    
    return noErr;
}

std::array<uint8_t, 2> AACEncoderCpp::makeAsc()
{
    // http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Audio_Specific_Config
    std::array<uint8_t, 2> asc;
    uint8_t sampleRateIndex = getSampleRateIndex(m_sampleRate);
    asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x3);
    asc[1] = ((sampleRateIndex & 0x1)<<7) | ((m_channels & 0xF) << 3);
    return asc;
}

void AACEncoderCpp::putFrame(CMSampleBufferRef audioFrame) {
    AudioBufferList inAaudioBufferList;
    CMBlockBufferRef blockBuffer;
    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(audioFrame, NULL, &inAaudioBufferList, sizeof(inAaudioBufferList), NULL, NULL, 0, &blockBuffer);
    //NSAssert(inAaudioBufferList.mNumberBuffers == 1, nil);
    
    if(inputLog != nullptr) {
        CMFormatDescriptionRef formatDescription =
        CMSampleBufferGetFormatDescription(audioFrame);
        
        const AudioStreamBasicDescription* const asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
        *inputLog << "IN: pts = " << CMSampleBufferGetPresentationTimeStamp(audioFrame).value
        << ", pts.scale = " << CMSampleBufferGetPresentationTimeStamp(audioFrame).timescale <<  ", formatID = " << asbd->mFormatID << ", format flags = " << asbd->mFormatFlags << ", sampleRate = " << asbd->mSampleRate << ", channels = " << asbd->mChannelsPerFrame << ", frames = " << asbd->mFramesPerPacket << ", bytesPerFrame = " << asbd->mBytesPerFrame << ", bytesPerPacket = " << asbd->mBytesPerPacket << ", size = " << inAaudioBufferList.mBuffers[0].mDataByteSize << ", buffers = " << inAaudioBufferList.mNumberBuffers << std::endl;
    }

    
    
    memcpy(m_inputBuffer + m_inputBufferLength, (uint8_t*)inAaudioBufferList.mBuffers[0].mData, inAaudioBufferList.mBuffers[0].mDataByteSize);
    m_inputBufferLength += inAaudioBufferList.mBuffers[0].mDataByteSize;
    CFRelease(blockBuffer);

    
    uint32_t size = m_inputBufferLength;
    uint8_t* data = m_inputBuffer;

    
//    AudioBufferList outAudioBufferList;
//    outAudioBufferList.mNumberBuffers = 1;
//    outAudioBufferList.mBuffers[0].mNumberChannels = inAaudioBufferList.mBuffers[0].mNumberChannels;
//    outAudioBufferList.mBuffers[0].mDataByteSize = bufferSize;
//    outAudioBufferList.mBuffers[0].mData = buffer;
//    
//    UInt32 ioOutputDataPacketSize = 1;
    
    //NSAssert(AudioConverterFillComplexBuffer(audioConverter, inInputDataProc, &inAaudioBufferList, &ioOutputDataPacketSize, &outAudioBufferList, NULL) == 0, nil);
    
    //NSData *data = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
    
    

    
    
    const size_t sampleCount = size / m_bytesPerSample;
    const size_t aac_packet_count = sampleCount / kSamplesPerFrame;
    const size_t required_bytes = aac_packet_count * m_outputPacketMaxSize;
    
    
    if(aac_packet_count > 0)
    {
        //for(int i=0;i<size;i++,m_sampleIndex++) if( (m_sampleIndex/44100)%2 == 0 ) data[i] = 0;
        
        //uint8_t *buffer = (uint8_t *)malloc(required_bytes);
        
        //memset(buffer, 0, required_bytes);
        m_outputBuffer.resize(required_bytes);
        
        uint8_t* p = &m_outputBuffer[0];
        uint8_t* p_out = (uint8_t*)data;
        
        //std::cout << "size = " << size << ", bytesPerSample = " << m_bytesPerSample << ", sampleCount = " << sampleCount << ", aac packet count = " << aac_packet_count << ", required bytes = " << required_bytes << std::endl;
        
        for ( size_t i = 0 ; i < aac_packet_count ; ++i ) {
            UInt32 num_packets = 1;
            
            AudioBufferList l;
            l.mNumberBuffers=1;
            l.mBuffers[0].mDataByteSize = m_outputPacketMaxSize * num_packets;
            l.mBuffers[0].mData = p;
            
            std::unique_ptr<UserData> ud(new UserData());
            ud->size = static_cast<int>(kSamplesPerFrame * m_bytesPerSample);
            ud->data = const_cast<uint8_t*>(p_out);
            ud->packetSize = static_cast<int>(m_bytesPerSample);
            
            AudioStreamPacketDescription output_packet_desc[num_packets];
            //m_encoderLock.lock();
            OSStatus result;
            if(noErr != (result = AudioConverterFillComplexBuffer(m_audioEncoder, AACEncoderCpp::ioProc, ud.get(), &num_packets, &l, output_packet_desc)))
            {
                *outputLog << "Encoder result: " << result << std::endl;
            }
            //m_encoderLock.unlock();
            
            p += output_packet_desc[0].mDataByteSize;
            p_out += kSamplesPerFrame * m_bytesPerSample;
        }
        const size_t totalBytes = p - &m_outputBuffer[0];;

        //std::cout << "AAC encoder input data: " << size << " bytes, output data: " << totalBytes << " bytes" << std::endl;
        
    //    auto output = m_output.lock();
    //    if(output && totalBytes) {
    //        if(!m_sentConfig) {
    //            output->pushBuffer((const uint8_t*)m_asc, sizeof(m_asc), metadata);
    //            m_sentConfig = true;
    //        }
    //        
    //        output->pushBuffer(m_outputBuffer(), totalBytes, metadata);
    //    }
        
        if(totalBytes > 0 && m_compressedDataCallback)
        {
            CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(audioFrame);
            if(outputLog != nullptr) {
                *outputLog << "OUT: pts = " << timestamp.value << ", size = " << totalBytes << std::endl;
            }
            m_compressedDataCallback(&m_outputBuffer[0], totalBytes, makeAsc(), timestamp);
        }
        
        m_inputBufferLength = 0;
    }
    
}
