//
//  H264Encoder.cpp
//  CameraTest
//
//  Created by alex on 05/03/2017.
//  Copyright © 2017 alex. All rights reserved.
//

#include "H264EncoderCpp.h"
#include <iostream>
#include <VideoToolbox/VTPixelTransferProperties.h>

void videoEncoderCallback(void *outputCallbackRefCon,
                void *sourceFrameRefCon,
                OSStatus status,
                VTEncodeInfoFlags infoFlags,
                CMSampleBufferRef sampleBuffer )
{
    //CVPixelBufferRef pixbuf = (CVPixelBufferRef)sourceFrameRefCon;
    //CFRelease(pixbuf);
    if (status != noErr) {
        return;
    }
    if ((infoFlags & kVTEncodeInfo_FrameDropped)) {
        //DVLOG(2) << __func__ << " frame dropped";
        return;
    }
    CMItemCount sample_count = CMSampleBufferGetNumSamples(sampleBuffer);
    if (sample_count > 1) {
         return;
    }
    ((H264EncoderCpp*)outputCallbackRefCon)->signalCompressedData(sampleBuffer);
}

H264EncoderCpp::H264EncoderCpp(int width, int height, int bitrate, int frameRate, std::function<void(CMSampleBufferRef)> compressedDataCallback)
{
    m_width = width;
    m_height = height;
    m_bitrate = bitrate;
    m_frameRate = frameRate;
    m_compressedDataCallback = compressedDataCallback;
    initCompressionSession();
}

H264EncoderCpp::~H264EncoderCpp()
{
    closeCompressionSession();
}

void H264EncoderCpp::initCompressionSession()
{
    //m_encoderLock.lock();
    OSStatus err = noErr;
//    CFMutableDictionaryRef encoderSpecifications = nullptr;
    CFMutableDictionaryRef sessionAttributes = CFDictionaryCreateMutable(
                                                                         NULL,
                                                                         0,
                                                                         &kCFTypeDictionaryKeyCallBacks,
                                                                         &kCFTypeDictionaryValueCallBacks);

//    float fixedQuality = 0.25;
//    CFNumberRef qualityNum = CFNumberCreate(NULL, kCFNumberFloat32Type, &fixedQuality);
//    CFDictionarySetValue(sessionAttributes, kVTCompressionPropertyKey_Quality, qualityNum);
//    CFRelease(qualityNum);
    int fixedBitrate = m_bitrate; // 2000 * 1024 -> assume 2 Mbits/s
    CFNumberRef bitrateNum = CFNumberCreate(NULL, kCFNumberSInt32Type, &fixedBitrate);
    CFDictionarySetValue(sessionAttributes, kVTCompressionPropertyKey_AverageBitRate, bitrateNum);
    CFRelease(bitrateNum);
    
    VTCompressionSessionRef session = nullptr;
    SInt32 cvPixelFormatTypeValue = ::kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;//::kCVPixelFormatType_32BGRA;
        SInt8  boolYESValue = 0xFF;
        
        CFDictionaryRef emptyDict = ::CFDictionaryCreate(kCFAllocatorDefault, nil, nil, 0, nil, nil);
        CFNumberRef cvPixelFormatType = ::CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, (const void*)(&(cvPixelFormatTypeValue)));
        CFNumberRef frameW = ::CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, (const void*)(&(m_width)));
        CFNumberRef frameH = ::CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, (const void*)(&(m_height)));
        CFNumberRef boolYES = ::CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt8Type, (const void*)(&(boolYESValue)));
        
        const void *pixelBufferOptionsDictKeys[] = { kCVPixelBufferPixelFormatTypeKey, kCVPixelBufferWidthKey,  kCVPixelBufferHeightKey,  kCVPixelBufferIOSurfacePropertiesKey};
        const void *pixelBufferOptionsDictValues[] = { cvPixelFormatType,  frameW, frameH, emptyDict};
        CFDictionaryRef pixelBufferOptions = ::CFDictionaryCreate(kCFAllocatorDefault, pixelBufferOptionsDictKeys, pixelBufferOptionsDictValues, 4, nil, nil);
    
    
        err = VTCompressionSessionCreate(
                                         kCFAllocatorDefault,
                                         m_width,
                                         m_height,
                                         kCMVideoCodecType_H264,
                                         sessionAttributes,
                                         pixelBufferOptions,
                                         NULL,
                                         &videoEncoderCallback,
                                         this,
                                         &session);
        
        CFRelease(emptyDict);
        CFRelease(cvPixelFormatType);
        CFRelease(frameW);
        CFRelease(frameH);
        CFRelease(boolYES);
        CFRelease(pixelBufferOptions);
    
    
//    if(err == noErr) {
//        m_compressionSession = session;
//
//        const int32_t v = 1.5*m_frameRate; // 2-second kfi
//
//        CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
//        err = VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameInterval, ref);
//        CFRelease(ref);
//    }

    if(err == noErr) {
        m_compressionSession = session;
        
        const int32_t v = 4; // 2-second kfi
        
        CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
        err = VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, ref);
        CFRelease(ref);
    }

    
    /*if(err == noErr) {
        const int v = m_frameRate;
        CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
        err = VTSessionSetProperty(session, kVTCompressionPropertyKey_ExpectedFrameRate, ref);
        CFRelease(ref);
    }*/
//    if(err == noErr) {
//        const int v = 4;
//        CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
//        err = VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxFrameDelayCount, ref);
//        CFRelease(ref);
//    }
    
    if(err == noErr) {
        err = VTSessionSetProperty(session , kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
    }
    
//    if(err == noErr) {
//        const int v = m_bitrate;
//        CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
//        err = VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, ref);
//        CFRelease(ref);
//    }
//
//    float fixedQuality = 0.25;
//    CFNumberRef qualityNum = CFNumberCreate(NULL, kCFNumberFloat32Type, &fixedQuality);
//    VTSessionSetProperty(session, kVTCompressionPropertyKey_Quality, qualityNum);
//    CFRelease(qualityNum);
    
    if(err == noErr) {
        err = VTSessionSetProperty(session, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    }
    
    if(err == noErr) {
        err = VTSessionSetProperty(session, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    }
    if(err == noErr) {
        err = VTSessionSetProperty(session, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CAVLC);
    }
    if(err == noErr) {
        VTCompressionSessionPrepareToEncodeFrames(session);
    }
    //m_encoderLock.unlock();
}

void H264EncoderCpp::closeCompressionSession()
{
    if(m_compressionSession) {
        VTCompressionSessionInvalidate((VTCompressionSessionRef)m_compressionSession);
        CFRelease((VTCompressionSessionRef)m_compressionSession);
        m_compressionSession = nullptr;
    }
}

void H264EncoderCpp::signalCompressedData(CMSampleBufferRef compressedData)
{
    if(m_compressedDataCallback) m_compressedDataCallback(compressedData);
}

void H264EncoderCpp::putFrame(CVPixelBufferRef pixelBuffer, CMTime timestamp)
{
    if(m_compressionSession) {
        //m_encoderLock.lock();
        VTCompressionSessionRef session = (VTCompressionSessionRef)m_compressionSession;
        
        CMTime dur = CMTimeMake(1, m_frameRate);
        VTEncodeInfoFlags flags;
        
        
        CFMutableDictionaryRef frameProps = NULL;
        
//        if(m_forceKeyframe) {
//            s_forcedKeyframePTS = pts.value;
//            
//            frameProps = CFDictionaryCreateMutable(kCFAllocatorDefault, 1,&kCFTypeDictionaryKeyCallBacks,                                                            &kCFTypeDictionaryValueCallBacks);
//            
//            
//            CFDictionaryAddValue(frameProps, kVTEncodeFrameOptionKey_ForceKeyFrame, kCFBooleanTrue);
//        }
        
        
        OSStatus err = VTCompressionSessionEncodeFrame(session, pixelBuffer, timestamp, /*dur*/kCMTimeInvalid,  frameProps, pixelBuffer, &flags);
        /*if(err != noErr)
        {
            closeCompressionSession();
            initCompressionSession();
        }*/
        
//        if(m_forceKeyframe) {
//            CFRelease(frameProps);
//            m_forceKeyframe = false;
//        }
        
        //m_encoderLock.unlock();
    }
}

int H264EncoderCpp::getQueueLength()
{
    OSStatus status;
    CFNumberRef value;
    int frames = 0;
    
    status = VTSessionCopyProperty (m_compressionSession,
                                    kVTCompressionPropertyKey_NumberOfPendingFrames, NULL, &value);
    if (status != noErr || !value) {
        return 0;
    }
    
    CFNumberGetValue (value, kCFNumberSInt32Type, &frames);
    CFRelease (value);
    return frames;
}

CVPixelBufferPoolRef H264EncoderCpp::pixelBufferPool()
{
    if(m_compressionSession) {
        return VTCompressionSessionGetPixelBufferPool((VTCompressionSessionRef)m_compressionSession);
    }
    return nullptr;
}
