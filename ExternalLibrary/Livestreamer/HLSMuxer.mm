//
//  HLSMuxer.m
//  MultiStreamer
//
//  Created by alex on 27/04/2018.
//  Copyright © 2018 alex. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "HLSSegmenter/HLSSegmenter.h"
#include "TSMuxer/TSMuxer.h"
#include "Media/MediaCallback.h"
#include "Media/AVCCParser.h"
#include "Media/CircularBufferStatic.h"
#import "HLSMuxer.h"
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <array>
#import <fstream>
#include <cstdio>

@interface HLSMuxer() {
    std::unique_ptr<TSMuxer> m_tsMuxer;
    std::unique_ptr<HLSPlaylistBuilder> m_playlist;
    uint32_t m_videoTrackID;
    uint32_t m_audioTrackID;
    bool m_firstVideoFrameSent;
    bool m_firstAudioFrameSent;
    dispatch_queue_t queue;
    double m_lastKeyFramePTS;
    MediaFrame frame;
    MediaFrame audioFrame;
    std::mutex m_muxerLock;
    std::unique_ptr<std::ofstream> outputLog;
    
    std::unique_ptr<CircularBufferStatic> audioQueue;
    CMSimpleQueueRef videoQueue;
}
@end


@implementation HLSMuxer

-(id) initWithTargetAddress:(NSString*)address {
    self = [self init];
    if(self) {
        try
        {
            std::string homePath = [NSHomeDirectory() UTF8String];
            std::ofstream output(homePath + "/Documents/a.m3u8", std::ofstream::binary);
            output << "#EXTM3U" << std::endl;
            output << "#EXT-X-VERSION:3" << std::endl;
            output << "#EXT-X-STREAM-INF:BANDWIDTH=1228571,CODECS=\"avc1.42001f,mp4a.40.2\"" << std::endl;
            output << "playlist.m3u8" << std::endl;

            audioQueue = std::make_unique<CircularBufferStatic>(1024*512);
            CMSimpleQueueCreate(kCFAllocatorDefault, 60, &videoQueue);
            queue = dispatch_queue_create("com.example.playlist.renderer", NULL);
            
            m_playlist = std::make_unique<HLSPlaylistBuilder>(homePath + "/Documents/playlist.m3u8", 5);
            m_playlist->Render();
            m_playlist->toBeRemoved = [self, homePath](HLSPlaylistEntry entry) {
                try
                {
                    remove(std::string(homePath + "/Documents/" + entry.path).c_str());
                }
                catch(std::exception& ex) { }
                catch(...) { }
            };
            auto callback = [self, homePath](TSSegment segment) {
                dispatch_async(queue, ^{
                    try
                    {
                        if (!segment.IsEmpty()) segment.Render(homePath + "/Documents/");
                        //*outputLog << "new segment " << segment.GetIndex() << std::endl;
                        m_playlist->PutFrame(HLSPlaylistEntry(segment.Path(), 4, segment.GetIndex()));
                        m_playlist->Render();
                    }
                    catch(std::exception& ex)
                    {
                        
                    }
                    catch(...)
                    {
                        
                    }
                });
            };
            auto hlsSegmenter = std::make_shared<HLSSegmenter>(std::make_shared<MediaCallback<TSSegment>>(callback), homePath + "/Documents/");
            m_tsMuxer = std::make_unique<TSMuxer>(hlsSegmenter);
            m_videoTrackID = m_tsMuxer->AddTrack(MediaDescriptor(MediaType::Video, MediaCodec::VideoH264));
            m_audioTrackID = m_tsMuxer->AddTrack(MediaDescriptor(MediaType::Audio, MediaCodec::AudioAAC));
            m_firstVideoFrameSent = false;
            m_firstAudioFrameSent = false;
            m_lastKeyFramePTS = 0;
            frame.Descriptor().type = MediaType::Video;
            frame.Descriptor().codec = MediaCodec::VideoH264;
            audioFrame.Descriptor().type = MediaType::Audio;
            audioFrame.Descriptor().codec = MediaCodec::AudioAAC;
            
            //outputLog = std::unique_ptr<std::ofstream>( new std::ofstream(homePath + "/Documents/hls.txt"));
            //*outputLog << "hi" << std::endl;

            NSLog(@"HLS muxer created");
        }
        catch(std::exception& ex)
        {
            NSLog(@"%s", ex.what());
            [self stop];
            return nil;
        }
    }
    return self;
}

-(void)dequeueVideoSample {
    CMSampleBufferRef sampleBuffer;
    if((sampleBuffer = (CMSampleBufferRef)CMSimpleQueueDequeue(videoQueue)) != nil) {
        
        frame.Data().resize(0);
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        //CMTime dts = CMSampleBufferGetDecodeTimeStamp(sampleBuffer);
        //MediaFrame frame(MediaType::Video, MediaCodec::VideoH264);
        frame.SetPTS(CMTimeGetSeconds(pts));
        //firstFrame = false;
        BitstreamWriter frameWriter = frame.GetDataWriter();
        //frameWriter.PutBytes(currentFrameData.cbegin(), currentFrameData.cend());
        //std::cout << "Media frame " << frame.Data().size() << " bytes" << std::endl;
        //muxer.PutFrame(frame, videoTrackID);
        //currentFrameData.clear();
        BOOL isKeyframe = NO;
        if(attachments != NULL)
        {
            CFDictionaryRef attachment = (CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
            CFBooleanRef dependsOnOthers = (CFBooleanRef)CFDictionaryGetValue(attachment, kCMSampleAttachmentKey_DependsOnOthers);
            isKeyframe = (dependsOnOthers == kCFBooleanFalse);
        }
        
        frame.SetKeyFrame(isKeyframe/* && fabs(frame.PTS() - m_lastKeyFramePTS) > 2*/);
        //if(frame.KeyFrame()) m_lastKeyFramePTS = frame.PTS();
        uint8_t au_buf[6];
        au_buf[0] = 0;
        au_buf[1] = 0;
        au_buf[2] = 0;
        au_buf[3] = 2;
        au_buf[4] = 9;
        au_buf[5] = isKeyframe ? 0x10 : 0x30;
        frameWriter.PutBytes(au_buf, au_buf + 6);
        
        if(isKeyframe)
        {
            // Send the SPS and PPS.
            CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
            size_t spsSize, ppsSize;
            size_t parmCount;
            const uint8_t* sps, *pps;
            
            int spsHeaderSize = 4;
            int ppsHeaderSize = 4;
            
            OSStatus status;
            
            status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sps, &spsSize, &parmCount, NULL );
            if( status != noErr )
            {
                NSLog(@"Error getting of sps NAL");
            }
            else
            {
                uint8_t sps_buf[spsSize + spsHeaderSize];
                
                memcpy(&sps_buf[spsHeaderSize], sps, spsSize);
                //memcpy(&sps_buf[0], &spsSize, spsHeaderSize);
                sps_buf[0] = 0;
                sps_buf[1] = 0;
                sps_buf[2] = 0;
                sps_buf[3] = (uint8_t)spsSize;
                spsSize += spsHeaderSize ;
                
                //SPAVBufferData *spsData = [[SPAVBufferData alloc] initWithBytes:sps_buf size:spsSize pts:pts dts:dts pos:encoder.bufferPos keyFrame:isKeyframe];
                //[encoder _compressionSessionOutput:spsData];
                frameWriter.PutBytes(sps_buf, sps_buf + spsSize);
            }
            
            status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pps, &ppsSize, &parmCount, NULL );
            if( status != noErr )
            {
                NSLog(@"Error getting of pps NAL");
            }
            else
            {
                uint8_t pps_buf[ppsSize + ppsHeaderSize];
                
                memcpy(&pps_buf[ppsHeaderSize], pps, ppsSize);
                
                //memcpy(&pps_buf[0], &ppsSize, ppsHeaderSize);
                pps_buf[0] = 0;
                pps_buf[1] = 0;
                pps_buf[2] = 0;
                pps_buf[3] = (uint8_t)ppsSize;
                ppsSize += ppsHeaderSize;
                
                
                //            SPAVBufferData *ppsData = [[SPAVBufferData alloc] initWithBytes:pps_buf size:ppsSize pts:pts dts:dts pos:encoder.bufferPos keyFrame:isKeyframe];
                //            [encoder _compressionSessionOutput:ppsData];
                frameWriter.PutBytes(pps_buf, pps_buf + ppsSize);
            }
        }
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        
        if( blockBuffer )
        {
        
        
            size_t  length;
            char    *dataBytes;
            
            OSStatus dataStatus = CMBlockBufferGetDataPointer(blockBuffer, 0, 0, &length, &dataBytes);
            
            if( dataStatus == kCMBlockBufferNoErr )
            {
                frameWriter.PutBytes(dataBytes, dataBytes + length);
                if(m_firstVideoFrameSent || frame.KeyFrame()) {
                    m_firstVideoFrameSent = true;
                    AVCCParser avcc;
                    avcc.ConvertToAnnexB(frame.Data());
                    //std::lock_guard<std::mutex> lock(m_muxerLock);
                    m_tsMuxer->PutFrame(frame, m_videoTrackID);
                }
            }
            
        }
        
        CFRelease(sampleBuffer);
    }
}

-(double)peekVideoPTS {
    CMSampleBufferRef sampleBuffer;
    if((sampleBuffer = (CMSampleBufferRef)CMSimpleQueueGetHead(videoQueue)) != nil) {
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        return CMTimeGetSeconds(pts);
    }
    return 0;
}

-(double)peekAudioPTS {
    CMTime pts;
    if(audioQueue->GetWaterLevel() >= sizeof(pts))
    {
        audioQueue->Peek((uint8_t*)&pts, sizeof(pts));
        return CMTimeGetSeconds(pts);
    }
    return 0;
}

-(void) putVideoSample:(CMSampleBufferRef)sampleBuffer {
    try
    {
        CFRetain(sampleBuffer);
        if(noErr != CMSimpleQueueEnqueue(videoQueue, sampleBuffer)) {
            CFRelease(sampleBuffer);
        }

        while(CMSimpleQueueGetCount(videoQueue) > 0 && audioQueue->GetWaterLevel() > 0) {
            //if(outputLog) *outputLog << "peeking pts" << std::endl;
            double videoPts = [self peekVideoPTS];
            double audioPts = [self peekAudioPTS];
            
            //if(outputLog) *outputLog << "videoPts = " << videoPts << ", audioPts = " << audioPts << std::endl;
            
            if(audioPts < videoPts) {
                [self dequeueAudioSample];
            } else {
                [self dequeueVideoSample];
            }
        }
       // [self dequeueVideoSample];
        
        if(CMSimpleQueueGetCount(videoQueue) > 40 && audioQueue->GetWaterLevel() == 0) {
            [self dequeueVideoSample];
            if(outputLog) *outputLog << "too long video queue" << std::endl;
        }
        

    }
    catch(std::exception& ex) {
        NSLog(@"%s", ex.what());
        //if(self.delegate != nil) [self.delegate onError:[NSString stringWithUTF8String:ex.what()]];
    }
}

-(void)dequeueAudioSample {
    if(audioQueue->GetWaterLevel() > 0)
    {
        
        CMTime pts;
        size_t frameSize;
        audioQueue->Read((uint8_t*)&pts, sizeof(pts));
        audioQueue->Read((uint8_t*)&frameSize, sizeof(frameSize));
        audioFrame.Data().resize(frameSize);
        audioQueue->Read(&audioFrame.Data()[0], frameSize);
        
        //if(outputLog) *outputLog << "IN: " << pts.value << std::endl;
        audioFrame.SetPTS(CMTimeGetSeconds(pts));
        audioFrame.SetKeyFrame(false);
        
        /*if(frame.KeyFrame()) {
         frameWriter.PutBytes((uint8_t*)asc.bytes, (uint8_t*)asc.bytes + asc.length);
         }
         else {
         frameWriter.PutBytes((uint8_t*)data.bytes, (uint8_t*)data.bytes + data.length);
         }
         m_firstAudioFrameSent = true;*/
        
        //uint64_t fullFrameSize = 7 + data.length;
        
        /* adts_fixed_header */
        //        frameWriter.PutBits(0xFFFFFF, 12);   /* syncword */
        //        frameWriter.PutBits(0, 1); /* ID */
        //        frameWriter.PutBits(0, 2); /* layer */
        //        frameWriter.PutBits(1, 1); /* protection_absent */
        //        frameWriter.PutBits(1, 2); /* profile_objecttype minus one */
        //        frameWriter.PutBits(4, 4); /* sample_rate_index */
        //        frameWriter.PutBits(0, 1); /* private_bit */
        //        frameWriter.PutBits(1, 3); /* channel_configuration */
        //        frameWriter.PutBits(0, 1); /* original_copy */
        //        frameWriter.PutBits(0, 1); /* home */
        //
        //        /* adts_variable_header */
        //        frameWriter.PutBits(0, 1); /* copyright_identification_bit */
        //        frameWriter.PutBits(0, 1); /* copyright_identification_start */
        //        frameWriter.PutBits(fullFrameSize, 13); /* aac_frame_length */
        //        frameWriter.PutBits(0x7FF, 11); /* adts_buffer_fullness */
        //        frameWriter.PutBits(0, 2); /* number_of_raw_data_blocks_in_frame minus one*/
        
        
        //std::lock_guard<std::mutex> lock(m_muxerLock);
        m_tsMuxer->PutFrame(audioFrame, m_audioTrackID);
        //if(outputLog) *outputLog << "ok" << std::endl;
    }
}

-(void) putAudioSample:(uint8_t*)data size:(size_t)size pts:(CMTime)pts {
    try
    {
        if(audioQueue->GetMaxWriteSize() > sizeof(pts) + sizeof(size) + size) {
            audioQueue->Write((uint8_t*)&pts, sizeof(pts));
            audioQueue->Write((uint8_t*)&size, sizeof(size));
            audioQueue->Write(data, size);
        }
        else {
            if(outputLog) *outputLog << "audio queue overflow" << std::endl;
        }

        //[self dequeueAudioSample];
    }
    catch(std::exception& ex) {
        NSLog(@"%s", ex.what());
        //if(self.delegate != nil) [self.delegate onError:[NSString stringWithUTF8String:ex.what()]];
    }
}

-(void) stop {
    try
    {
        NSLog(@"streamer stop request");
        m_tsMuxer.reset();
    }
    catch(std::exception&) { }
    catch(...) {
        //ignore connection closing errors
    }
}

@end
