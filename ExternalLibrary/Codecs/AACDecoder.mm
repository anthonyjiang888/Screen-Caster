//
//  AACDecoder.m
//  LiveStreamer
//
//  Created by alex on 02/08/2017.
//  Copyright © 2017 alex. All rights reserved.
//

#import "AACDecoder.h"

const uint32_t kNoMoreDataErr = 'MOAR';

@implementation AACDecoder
    
- (void)setupAudioConverter{
    /*AudioStreamBasicDescription outFormat;
    memset(&outFormat, 0, sizeof(outFormat));
    outFormat.mSampleRate       = 44100;
    outFormat.mFormatID         = kAudioFormatLinearPCM;
    outFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    outFormat.mBytesPerPacket   = 2;
    outFormat.mFramesPerPacket  = 1;
    outFormat.mBytesPerFrame    = 2;
    outFormat.mChannelsPerFrame = 1;
    outFormat.mBitsPerChannel   = 16;
    outFormat.mReserved         = 0;
    
    
    AudioStreamBasicDescription inFormat;
    memset(&inFormat, 0, sizeof(inFormat));
    inFormat.mSampleRate        = 44100;
    inFormat.mFormatID          = kAudioFormatMPEG4AAC;
    inFormat.mFormatFlags       = kMPEG4Object_AAC_LC;
    inFormat.mBytesPerPacket    = 0;
    inFormat.mFramesPerPacket   = 1024;
    inFormat.mBytesPerFrame     = 0;
    inFormat.mChannelsPerFrame  = 1;
    inFormat.mBitsPerChannel    = 0;
    inFormat.mReserved          = 0;
    */
    AudioStreamBasicDescription outFormat;
    memset(&outFormat, 0, sizeof(outFormat));
    outFormat.mSampleRate       = 22050;
    outFormat.mFormatID         = kAudioFormatLinearPCM;
    outFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    outFormat.mBytesPerPacket   = 2*2;
    outFormat.mFramesPerPacket  = 1;
    outFormat.mBytesPerFrame    = 2*2;
    outFormat.mChannelsPerFrame = 2;
    outFormat.mBitsPerChannel   = 16;
    outFormat.mReserved         = 0;
    
    
    AudioStreamBasicDescription inFormat;
    memset(&inFormat, 0, sizeof(inFormat));
    inFormat.mSampleRate        = 22050;
    inFormat.mFormatID          = kAudioFormatMPEG4AAC;
    inFormat.mFormatFlags       = kMPEG4Object_AAC_LC;
    inFormat.mBytesPerPacket    = 0;
    inFormat.mFramesPerPacket   = 1024;
    inFormat.mBytesPerFrame     = 0;
    inFormat.mChannelsPerFrame  = 2;
    inFormat.mBitsPerChannel    = 0;
    inFormat.mReserved          = 0;
    
    OSStatus status =  AudioConverterNew(&inFormat, &outFormat, &_audioConverter);
    /*AudioClassDescription codecsRequest[2] = {
        {
            kAudioDecoderComponentType,
            kAudioFormatMPEG4AAC,
            kAppleSoftwareAudioCodecManufacturer
        },
        {
            kAudioDecoderComponentType,
            kAudioFormatMPEG4AAC,
            kAppleHardwareAudioCodecManufacturer
        }
    };
    
    OSStatus status = AudioConverterNewSpecific(&inFormat, &outFormat, 2, codecsRequest, &_audioConverter);*/

    if (status != 0) {
        printf("setup converter error, status: %i\n", (int)status);
    }
    else printf("AAC decoder setup OK\n");
}

struct PassthroughUserData {
    UInt32 mChannels;
    UInt32 mDataSize;
    const void* mData;
    AudioStreamPacketDescription mPacket;
};


OSStatus inInputDataProc(AudioConverterRef aAudioConverter,
                         UInt32* aNumDataPackets /* in/out */,
                         AudioBufferList* aData /* in/out */,
                         AudioStreamPacketDescription** aPacketDesc,
                         void* aUserData)
{
    
    PassthroughUserData* userData = (PassthroughUserData*)aUserData;
    if (!userData->mDataSize) {
        *aNumDataPackets = 0;
        return kNoMoreDataErr;
    }
    
    if (aPacketDesc) {
        userData->mPacket.mStartOffset = 0;
        userData->mPacket.mVariableFramesInPacket = 0;
        userData->mPacket.mDataByteSize = userData->mDataSize;
        *aPacketDesc = &userData->mPacket;
    }
    
    aData->mBuffers[0].mNumberChannels = userData->mChannels;
    aData->mBuffers[0].mDataByteSize = userData->mDataSize;
    aData->mBuffers[0].mData = const_cast<void*>(userData->mData);
    
    // No more data to provide following this run.
    userData->mDataSize = 0;
    
    return noErr;
}
    
- (void)decodeAudioFrame:(NSData *)frame withPts:(CMTime)pts{
    if(!_audioConverter){
        [self setupAudioConverter];
    }
    
    PassthroughUserData userData = { 1, (UInt32)frame.length, [frame bytes]};
    NSMutableData *decodedData = [NSMutableData new];
    
    const uint32_t MAX_AUDIO_FRAMES = 1024;
    const uint32_t maxDecodedSamples = MAX_AUDIO_FRAMES * 1;
    
    do{
        uint8_t *buffer = (uint8_t *)malloc(maxDecodedSamples * sizeof(short int));
        AudioBufferList decBuffer;
        decBuffer.mNumberBuffers = 1;
        decBuffer.mBuffers[0].mNumberChannels = 1;
        decBuffer.mBuffers[0].mDataByteSize = maxDecodedSamples * sizeof(short int);
        decBuffer.mBuffers[0].mData = buffer;
        
        UInt32 numFrames = MAX_AUDIO_FRAMES;
        
        AudioStreamPacketDescription outPacketDescription;
        memset(&outPacketDescription, 0, sizeof(AudioStreamPacketDescription));
        outPacketDescription.mDataByteSize = MAX_AUDIO_FRAMES;
        outPacketDescription.mStartOffset = 0;
        outPacketDescription.mVariableFramesInPacket = 0;
        
        OSStatus rv = AudioConverterFillComplexBuffer(_audioConverter,
                                                      inInputDataProc,
                                                      &userData,
                                                      &numFrames /* in/out */,
                                                      &decBuffer,
                                                      &outPacketDescription);
        if (rv && rv != kNoMoreDataErr) {
            NSLog(@"Error decoding audio stream: %d\n", rv);
            break;
        }
        
        if (numFrames) {
            [decodedData appendBytes:decBuffer.mBuffers[0].mData length:decBuffer.mBuffers[0].mDataByteSize];
        }
        
        
        if(buffer) free(buffer);
        
        if (rv == kNoMoreDataErr) {
            break;
        }
        
    }while (true);
    if(self.delegate != nil) [self.delegate decompressedAudioDataReceived:decodedData pts:pts];
}
    
@end
