//
//  InfiniteAudio.m
//  ChromecastDisplay
//
//  Created by alex on 07/06/2018.
//  Copyright © 2018 alex. All rights reserved.
//

#import "InfiniteAudio.h"
#include "CircularBufferStatic.h"
#include "MediaFrame.h"
#include <fstream>

@interface InfiniteAudio() {
    CMSimpleQueueRef samplesQueue;
    CMTime currentPosition;
    std::unique_ptr<MediaFrame> outputFrame;
    std::unique_ptr<MediaFrame> inputFrame;
    std::unique_ptr<BitstreamReader> inputFrameReader;
    std::unique_ptr<BitstreamWriter> outputFrameWriter;
    std::unique_ptr<std::ofstream> log;
}
@end

@implementation InfiniteAudio

-(id) initWithSampleRate:(int)sampleRate channels:(int)channels targetEncoder:(FDKAACEncoder*)encoder {
    self = [self init];
    if(self) {
        self.sampleRate = sampleRate;
        self.channels = channels;
        self.encoder = encoder;
        currentPosition.value = 0;
        currentPosition.timescale = sampleRate * channels;
        outputFrame = std::make_unique<MediaFrame>();
        outputFrame->Data().resize(256000);
        outputFrame->Data().resize(0);
        outputFrameWriter = std::make_unique<BitstreamWriter>(outputFrame->GetDataWriter());
        inputFrame = std::make_unique<MediaFrame>();
        inputFrame->Data().resize(256000);
        inputFrame->Data().resize(0);
        CMSimpleQueueCreate(kCFAllocatorDefault, 30, &samplesQueue);
        std::string homePath = [NSHomeDirectory() UTF8String];
        //log = std::unique_ptr<std::ofstream>( new std::ofstream(homePath + "/Documents/mixer.txt"));
    }
    return self;
}

-(void) putCMSampleBuffer:(CMSampleBufferRef) sampleBuffer {
    CFRetain(sampleBuffer);
    if(noErr != CMSimpleQueueEnqueue(samplesQueue, sampleBuffer)) {
        CFRelease(sampleBuffer);
    }
    if(log) *log << "sample enqueued " << std::endl;

}

-(void)dequeueSampleToInputFrame {
    CMSampleBufferRef sampleBuffer;
    if((sampleBuffer = (CMSampleBufferRef)CMSimpleQueueDequeue(samplesQueue)) != nil) {
        AudioBufferList inAaudioBufferList;
        CMBlockBufferRef blockBuffer = nil;
        if(noErr != CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, &inAaudioBufferList, sizeof(inAaudioBufferList), NULL, NULL, 0, &blockBuffer))
        {
            //if(*inputLog) *inputLog << "sample get buffer error" << std::endl;
        }
        if(blockBuffer == nil) {
            //if(*inputLog) *inputLog << "blockBuffer == nil" << std::endl;
        }
        if(inAaudioBufferList.mNumberBuffers != 1) {
            //if(*inputLog) *inputLog << "buffers Number != 1: " << inAaudioBufferList.mNumberBuffers << std::endl;
        }
        
        //NSAssert(inAaudioBufferList.mNumberBuffers == 1, nil);
        
        CMTime sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        
        inputFrame->SetPTS(CMTimeGetSeconds(sampleTime));
        
        inputFrame->Data().resize(inAaudioBufferList.mBuffers[0].mDataByteSize);
        memcpy(&inputFrame->Data()[0], (uint8_t*)inAaudioBufferList.mBuffers[0].mData, inAaudioBufferList.mBuffers[0].mDataByteSize);
        
        inputFrameReader = std::make_unique<BitstreamReader>(inputFrame->GetDataReader());
        
        while(inputFrameReader->RemainingDataSize() >= 2*self.channels && inputFrame->PTS() <= CMTimeGetSeconds(currentPosition) - 10.0 / (double)(self.sampleRate * self.channels)) {
            for(int i=0;i<self.channels;i++) {
                inputFrameReader->GetByte();
                inputFrameReader->GetByte();
                inputFrame->SetPTS(inputFrame->PTS() + 1.0 / (double)(self.sampleRate * self.channels));
            }
        }
        
        CFRelease(blockBuffer);
        CFRelease(sampleBuffer);
        if(log) *log << "sample dequeued with PTS = " << (double)inputFrame->PTS() << " and current pos is " << (double)CMTimeGetSeconds(currentPosition) << ", queue length = " << CMSimpleQueueGetCount(samplesQueue) << std::endl;
    }
}

-(void) flushOutput {
    if(log) *log << "flushing output " << CMTimeGetSeconds(currentPosition) << std::endl;
    if(outputFrame->Data().size() > 0 && self.encoder != nil) [self.encoder putData:&outputFrame->Data()[0] size:outputFrame->Data().size() pts:CMTimeMake(outputFrame->PTS() * _sampleRate * _channels, _sampleRate * _channels)];
    outputFrame->Data().resize(0);
    outputFrameWriter = std::make_unique<BitstreamWriter>(outputFrame->GetDataWriter());
    outputFrame->SetPTS(CMTimeGetSeconds(currentPosition));
};

-(void) consumeToTime:(CMTime)time {
    
    if(currentPosition.value == 0) {
        outputFrame->SetPTS(CMTimeGetSeconds(time));
        currentPosition = CMTimeMake(outputFrame->PTS() * _sampleRate * _channels, _sampleRate * _channels);
    };
    
    if(log) *log << "consuming from " << (double)CMTimeGetSeconds(currentPosition) << " to PTS = " << (double)CMTimeGetSeconds(time) << std::endl;

    
    while(CMTimeGetSeconds(currentPosition) < CMTimeGetSeconds(time)) {
        for(int i=0;i<self.channels;i++) {
            if(inputFrameReader == nullptr || inputFrameReader->RemainingDataSize() < 2) {
                [self dequeueSampleToInputFrame];
            }
            if(inputFrameReader != nullptr && inputFrameReader->RemainingDataSize() >= 2 && inputFrame->PTS() <= CMTimeGetSeconds(currentPosition)) {
                outputFrameWriter->PutByte(inputFrameReader->GetByte());
                outputFrameWriter->PutByte(inputFrameReader->GetByte());
                inputFrame->SetPTS(inputFrame->PTS() + 1.0 / (double)(self.sampleRate * self.channels));
            }
            else{
                outputFrameWriter->PutByte(0);
                outputFrameWriter->PutByte(0);
            }
            currentPosition.value++;
            if(outputFrame->Data().size() >= 44100) [self flushOutput];
        }
    }
    
    if(log) *log << "done" << std::endl;

}

@end
