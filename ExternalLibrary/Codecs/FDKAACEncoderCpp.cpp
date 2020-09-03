//
//  FDKAACEncoderCpp.cpp
//  ChromecastDisplay
//
//  Created by alex on 01/06/2018.
//  Copyright © 2018 alex. All rights reserved.
//

#include "FDKAACEncoderCpp.h"


#include <inttypes.h>
#include <iostream>
#include <array>




FDKAACEncoderCpp::FDKAACEncoderCpp(int sampleRate, int channels, int bitrate, std::function<void(uint8_t*, size_t, CMTime)> compressedDataCallback):
    m_sampleRate(sampleRate),
    m_channels(channels),
    m_bitrate(bitrate),
    m_bytesPerSample(2),
    m_inputBufferLength(0),
    m_compressedDataCallback(compressedDataCallback)
{
    if(AACENC_OK != aacEncOpen(&hEncoder, 0x00, 2) || !hEncoder) throw std::runtime_error("can't open aac encoder");
    if(AACENC_OK != aacEncoder_SetParam(hEncoder, AACENC_AOT, AOT_AAC_LC)) throw std::runtime_error("can't set encoder object type");
    if(AACENC_OK != aacEncoder_SetParam(hEncoder, AACENC_BITRATE, bitrate)) throw std::runtime_error("can't set encoder bitrate");;
    if(AACENC_OK != aacEncoder_SetParam(hEncoder, AACENC_SAMPLERATE, sampleRate)) throw std::runtime_error("can't set encoder sample rate");;
    if(AACENC_OK != aacEncoder_SetParam(hEncoder, AACENC_CHANNELMODE, channels)) throw std::runtime_error("can't set encoder channels mode");;
    if (AACENC_OK != aacEncoder_SetParam(hEncoder, AACENC_TRANSMUX, TT_MP4_ADTS)) throw std::runtime_error("can't set encoder output format");
    if (aacEncEncode(hEncoder, NULL, NULL, NULL, NULL) != AACENC_OK) {
        fprintf(stderr, "Unable to initialize the encoder\n");
        throw std::runtime_error("Unable to initialize the encoder");
    }
    AACENC_InfoStruct info = {0};
    if (aacEncInfo(hEncoder, &info) != AACENC_OK) {
        fprintf(stderr, "Unable to get the encoder info\n");
        throw std::runtime_error("Unable to get the encoder info");
    }
    printf("fdk encoder initialized\n");
    
    m_inputSamplesPerFrame = info.inputChannels * info.frameLength;
    printf("WARNING: info.inputChannels = %i, frameLength = %i", info.inputChannels, info.frameLength);
    m_bytesPerSample = 2;
    m_channels = info.inputChannels;
}

FDKAACEncoderCpp::~FDKAACEncoderCpp() {
    if(hEncoder)
    {
        aacEncClose(&hEncoder);
        hEncoder = 0;
    }
}

uint8_t FDKAACEncoderCpp::getSampleRateIndex(uint32_t sampleRate) {
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


std::array<uint8_t, 2> FDKAACEncoderCpp::makeAsc()
{
    // http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Audio_Specific_Config
    std::array<uint8_t, 2> asc;
    uint8_t sampleRateIndex = getSampleRateIndex(m_sampleRate);
    asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x3);
    asc[1] = ((sampleRateIndex & 0x1)<<7) | ((m_channels & 0xF) << 3);
    return asc;
}

void FDKAACEncoderCpp::putFrame(CMSampleBufferRef audioFrame) {
    if(inputLog) *inputLog << "frame" << std::endl;
    AudioBufferList inAaudioBufferList;
    CMBlockBufferRef blockBuffer = nil;
    if(noErr != CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(audioFrame, NULL, &inAaudioBufferList, sizeof(inAaudioBufferList), NULL, NULL, 0, &blockBuffer))
    {
        if(inputLog) *inputLog << "sample get buffer error" << std::endl;
    }
    if(blockBuffer == nil) {
        if(inputLog) *inputLog << "blockBuffer == nil" << std::endl;
        return;
    }
    if(inAaudioBufferList.mNumberBuffers != 1) {
        if(inputLog) *inputLog << "buffers Number != 1: " << inAaudioBufferList.mNumberBuffers << std::endl;
    }
    
    //NSAssert(inAaudioBufferList.mNumberBuffers == 1, nil);
    
    CMTime sampleTime = CMSampleBufferGetPresentationTimeStamp(audioFrame);
    
    if(m_inputBufferLength > 0) sampleTime.value -= (uint64_t)sampleTime.timescale * ((uint64_t)m_inputBufferLength/(uint64_t)(m_bytesPerSample*m_channels)) / (uint64_t)m_sampleRate;
    
    if(inputLog != nullptr) {
        CMFormatDescriptionRef formatDescription =
        CMSampleBufferGetFormatDescription(audioFrame);
        
        CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(audioFrame);
        
        const AudioStreamBasicDescription* const asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
        *inputLog << "IN: pts = " << currentTime.value
        << ", pts.scale = " << currentTime.timescale <<  ", formatID = " << asbd->mFormatID << ", format flags = " << asbd->mFormatFlags << ", sampleRate = " << asbd->mSampleRate << ", channels = " << asbd->mChannelsPerFrame << ", frames = " << asbd->mFramesPerPacket << ", bytesPerFrame = " << asbd->mBytesPerFrame << ", bytesPerPacket = " << asbd->mBytesPerPacket << ", size = " << inAaudioBufferList.mBuffers[0].mDataByteSize << ", buffers = " << inAaudioBufferList.mNumberBuffers << ", diff = " << (currentTime.value - previousInputPTS.value)/(double)currentTime.timescale << ", prev pts.value = " << previousInputPTS.value << std::endl;
        previousInputPTS = currentTime;
    }
//
//    if(outputLog) {
//        *outputLog << "info.inputChannels = " << m_channels << ", frameLength = " << m_inputSamplesPerFrame << std::endl;
//    }

    
    
    memcpy(m_inputBuffer + m_inputBufferLength, (uint8_t*)inAaudioBufferList.mBuffers[0].mData, inAaudioBufferList.mBuffers[0].mDataByteSize);
    m_inputBufferLength += inAaudioBufferList.mBuffers[0].mDataByteSize;
    CFRelease(blockBuffer);
    
    
    
    
    uint8_t* data = m_inputBuffer;
    
    size_t sampleCount;
    
    while((sampleCount = m_inputBufferLength / m_bytesPerSample) >= m_inputSamplesPerFrame)
    {
        AACENC_BufDesc in_buf = { 0 }, out_buf = { 0 };
        AACENC_InArgs in_args = { 0 };
        AACENC_OutArgs out_args = { 0 };
        int in_identifier = IN_AUDIO_DATA;
        int in_size, in_elem_size = 2;
        int out_identifier = OUT_BITSTREAM_DATA;
        int out_size, out_elem_size = 1;
        void *in_ptr, *out_ptr;
        in_ptr = data;
        
        for(int i=0;i<m_inputSamplesPerFrame;i++) {
            uint8_t temp = data[i*2];
            data[i*2] = data[i*2+1];
            data[i*2+1] = temp;
        }
        
        in_size = m_inputBufferLength;//m_inputSamplesPerFrame * m_bytesPerSample;
        in_args.numInSamples = m_inputBufferLength/m_bytesPerSample; //m_inputSamplesPerFrame;
        in_buf.numBufs = 1;
        in_buf.bufs = &in_ptr;
        in_buf.bufferIdentifiers = &in_identifier;
        in_buf.bufSizes = &in_size;
        in_buf.bufElSizes = &in_elem_size;
        
        
        out_ptr = m_outputBuffer;
        out_size = sizeof(m_outputBuffer);
        out_elem_size = 1;
        out_buf.numBufs = 1;
        out_buf.bufs = &out_ptr;
        out_buf.bufferIdentifiers = &out_identifier;
        out_buf.bufSizes = &out_size;
        out_buf.bufElSizes = &out_elem_size;
        AACENC_ERROR encodeResult = aacEncEncode(hEncoder, &in_buf, &out_buf, &in_args, &out_args);
        if(AACENC_OK == encodeResult && m_compressedDataCallback) {
            int encodedFrameLength = out_args.numOutBytes;
            m_compressedDataCallback(m_outputBuffer, encodedFrameLength, sampleTime);
        }
        data += m_inputSamplesPerFrame * m_bytesPerSample;

        //out->SetTime(in->GetTime(), in->GetTime() + (inputSamplesPerFrame/(channelsCount))/(Ipp64f)sampleRate);
        sampleTime.value += (uint64_t)sampleTime.timescale * (uint64_t)m_inputSamplesPerFrame / (uint64_t)(m_sampleRate * m_channels);
        
        m_inputBufferLength -= m_inputSamplesPerFrame * m_bytesPerSample;
    }

    //move data to start
    if(m_inputBufferLength > 0)
    {
        memcpy(m_inputBuffer, data, m_inputBufferLength);
    }

    
}

void FDKAACEncoderCpp::putData(uint8_t* inData, size_t size, CMTime pts) {
    if(inputLog) *inputLog << "frame" << std::endl;

    
    CMTime sampleTime = pts;
    
    if(m_inputBufferLength > 0) sampleTime.value -= (uint64_t)sampleTime.timescale * ((uint64_t)m_inputBufferLength/(uint64_t)(m_bytesPerSample*m_channels)) / (uint64_t)m_sampleRate;
    
//    if(inputLog != nullptr) {
//        CMFormatDescriptionRef formatDescription =
//        CMSampleBufferGetFormatDescription(audioFrame);
//
//        CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(audioFrame);
//
//        const AudioStreamBasicDescription* const asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
//        *inputLog << "IN: pts = " << currentTime.value
//        << ", pts.scale = " << currentTime.timescale <<  ", formatID = " << asbd->mFormatID << ", format flags = " << asbd->mFormatFlags << ", sampleRate = " << asbd->mSampleRate << ", channels = " << asbd->mChannelsPerFrame << ", frames = " << asbd->mFramesPerPacket << ", bytesPerFrame = " << asbd->mBytesPerFrame << ", bytesPerPacket = " << asbd->mBytesPerPacket << ", size = " << inAaudioBufferList.mBuffers[0].mDataByteSize << ", buffers = " << inAaudioBufferList.mNumberBuffers << ", diff = " << (currentTime.value - previousInputPTS.value)/(double)currentTime.timescale << ", prev pts.value = " << previousInputPTS.value << std::endl;
//        previousInputPTS = currentTime;
//    }
    //
    //    if(outputLog) {
    //        *outputLog << "info.inputChannels = " << m_channels << ", frameLength = " << m_inputSamplesPerFrame << std::endl;
    //    }
    
    
    
    memcpy(m_inputBuffer + m_inputBufferLength, inData, size);
    m_inputBufferLength += size;
    
    
    
    
    uint8_t* data = m_inputBuffer;
    
    size_t sampleCount;
    
    while((sampleCount = m_inputBufferLength / m_bytesPerSample) >= m_inputSamplesPerFrame)
    {
        AACENC_BufDesc in_buf = { 0 }, out_buf = { 0 };
        AACENC_InArgs in_args = { 0 };
        AACENC_OutArgs out_args = { 0 };
        int in_identifier = IN_AUDIO_DATA;
        int in_size, in_elem_size = 2;
        int out_identifier = OUT_BITSTREAM_DATA;
        int out_size, out_elem_size = 1;
        void *in_ptr, *out_ptr;
        in_ptr = data;
        
        for(int i=0;i<m_inputSamplesPerFrame;i++) {
            uint8_t temp = data[i*2];
            data[i*2] = data[i*2+1];
            data[i*2+1] = temp;
        }
        
        in_size = m_inputBufferLength;//m_inputSamplesPerFrame * m_bytesPerSample;
        in_args.numInSamples = m_inputBufferLength/m_bytesPerSample; //m_inputSamplesPerFrame;
        in_buf.numBufs = 1;
        in_buf.bufs = &in_ptr;
        in_buf.bufferIdentifiers = &in_identifier;
        in_buf.bufSizes = &in_size;
        in_buf.bufElSizes = &in_elem_size;
        
        
        out_ptr = m_outputBuffer;
        out_size = sizeof(m_outputBuffer);
        out_elem_size = 1;
        out_buf.numBufs = 1;
        out_buf.bufs = &out_ptr;
        out_buf.bufferIdentifiers = &out_identifier;
        out_buf.bufSizes = &out_size;
        out_buf.bufElSizes = &out_elem_size;
        AACENC_ERROR encodeResult = aacEncEncode(hEncoder, &in_buf, &out_buf, &in_args, &out_args);
        if(AACENC_OK == encodeResult && m_compressedDataCallback) {
            int encodedFrameLength = out_args.numOutBytes;
            m_compressedDataCallback(m_outputBuffer, encodedFrameLength, sampleTime);
        }
        data += m_inputSamplesPerFrame * m_bytesPerSample;
        
        //out->SetTime(in->GetTime(), in->GetTime() + (inputSamplesPerFrame/(channelsCount))/(Ipp64f)sampleRate);
        sampleTime.value += (uint64_t)sampleTime.timescale * (uint64_t)m_inputSamplesPerFrame / (uint64_t)(m_sampleRate * m_channels);
        
        m_inputBufferLength -= m_inputSamplesPerFrame * m_bytesPerSample;
    }
    
    //move data to start
    if(m_inputBufferLength > 0)
    {
        memcpy(m_inputBuffer, data, m_inputBufferLength);
    }

}

