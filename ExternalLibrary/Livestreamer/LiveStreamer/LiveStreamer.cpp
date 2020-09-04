// LiveStreamer.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#include "FLVMuxer.h"
#include <iostream>
#include <fstream>
#include <iterator>
#include "MediaCallback.h"
#include "MediaBuffer.h"
#include "RTMPClient.h"
#include "RTMPToAVCTransformer.h"
#include "RTMPToAACTransformer.h"
#include "TSMuxer.h"
#include "AVCCParser.h"
#include "HLSSegmenter.h"

int main(int argc, char *argv[])
{
	try
	{
		/*if (argc < 3)
		{
			throw std::runtime_error("Usage: livestreamer inputFileName outputFileName.flv");
		}
		std::ifstream input(argv[1], std::ifstream::binary);
		MediaBuffer inputBuffer(std::istreambuf_iterator<char>(input), (std::istreambuf_iterator<char>()));
		std::cout << "input data size: " << inputBuffer.size() << std::endl;

		RTMPClient client("rtmp://ec2-52-59-28-240.eu-central-1.compute.amazonaws.com/myapp/test", StreamingDirection::Publish);

		std::ofstream output(argv[2], std::ofstream::binary);
		auto callback = [&output, &client](FLVFrame frame) {
			std::ostream_iterator<uint8_t> out(output);
			std::copy(frame.Data().cbegin(), frame.Data().cend(), out);
			client.PutFrame(frame);
		};
		FLVMuxer muxer(std::make_shared<MediaCallback<FLVFrame>>(callback));
		uint32_t videoTrackID = muxer.AddTrack(MediaDescriptor(MediaType::Video, MediaCodec::VideoH264));

		BitstreamReader reader(inputBuffer);
		if (reader.RemainingDataSize() < 4) throw std::runtime_error("no input data found");
		uint32_t last32Bits = uint32_t(reader.GetBits(32));
		MediaBuffer currentFrameData;
		BitstreamWriter writer(currentFrameData);
		bool firstFrame = true;
		uint32_t frameNum = 0;
		while (reader.RemainingDataSize() > 0)
		{
			if (last32Bits == (('F' << 24) | ('R' << 16) | ('A' << 8) | 'M'))
			{
				if (currentFrameData.size())
				{
					//put frame to muxer
					MediaFrame frame(MediaType::Video, MediaCodec::VideoH264);
					frame.SetKeyFrame(firstFrame);
					frame.SetPTS(frameNum++ * 0.04);
					firstFrame = false;
					BitstreamWriter frameWriter = frame.GetDataWriter();
					frameWriter.PutBytes(currentFrameData.cbegin(), currentFrameData.cend());
					std::cout << "Media frame " << frame.Data().size() << " bytes" << std::endl;
					muxer.PutFrame(frame, videoTrackID);
					currentFrameData.clear();
					writer.SetPosition(0);
				}
				if(reader.RemainingDataSize() > 4) last32Bits = uint32_t(reader.GetBits(32));
				else break;
			}
			else //shift-in one byte
			{
				uint8_t data = (last32Bits & 0xFF000000) >> 24;
				writer.PutByte(data);
				last32Bits = (last32Bits << 8) | reader.GetByte();
			}
		}*/
		/*RTMPClient client("rtmp://ec2-52-59-28-240.eu-central-1.compute.amazonaws.com/myapp/euronews", StreamingDirection::Play);
		IReceiverPtr<RTMPPacket> videoTransformer = std::make_shared<RTMPToAVCTransformer>(std::make_shared<MediaCallback<AVCFrame>>([](AVCFrame avc) {
			std::cout << "video received: " << avc.Data().size() << " bytes, pts = " << avc.PTS() << std::endl;
			for (size_t i = 0; i < avc.SPS().size(); i++) std::cout << "sps[" << i << "].size = " << avc.SPS()[i].size() << std::endl;
			for (size_t i = 0; i < avc.PPS().size(); i++) std::cout << "pps[" << i << "].size = " << avc.PPS()[i].size() << std::endl;
		}));
		IReceiverPtr<RTMPPacket> audioTransformer = std::make_shared<RTMPToAACTransformer>(std::make_shared<MediaCallback<MediaFrame>>([](MediaFrame aac) {
			std::cout << "audio received: " << aac.Data().size() << " bytes, pts = " << aac.PTS() << std::endl;
		}));
		client.SetVideoReceiver(videoTransformer);
		client.SetAudioReceiver(audioTransformer);
		std::cout << "done" << std::endl;
		std::cin.get();*/
        if (argc < 3)
        {
            throw std::runtime_error("Usage: livestreamer inputFileName outputFileName.ts");
        }
        std::ifstream input(argv[1], std::ifstream::binary);
        MediaBuffer inputBuffer(std::istreambuf_iterator<char>(input), (std::istreambuf_iterator<char>()));
        std::cout << "input data size: " << inputBuffer.size() << std::endl;
        HLSPlaylistBuilder playlist("playlist.m3u8", 10);
        auto callback = [&playlist](TSSegment segment) {
            if (!segment.IsEmpty()) segment.Render();
            playlist.PutFrame(HLSPlaylistEntry(segment.Path(), 3, segment.GetIndex()));
            playlist.Render();
        };
        auto hlsSegmenter = std::make_shared<HLSSegmenter>(std::make_shared<MediaCallback<TSSegment>>(callback));
        TSMuxer muxer(hlsSegmenter);
        uint32_t videoTrack = muxer.AddTrack(MediaDescriptor(MediaType::Video, MediaCodec::VideoH264));
        BitstreamReader reader(inputBuffer);
        if (reader.RemainingDataSize() < 4) throw std::runtime_error("no input data found");
        uint32_t last32Bits = uint32_t(reader.GetBits(32));
        MediaBuffer currentFrameData;
        BitstreamWriter writer(currentFrameData);
        bool firstFrame = true;
        uint32_t frameNum = 0;
        AVCCParser avcc;
        while (reader.RemainingDataSize() > 0)
        {
            if (last32Bits == (('F' << 24) | ('R' << 16) | ('A' << 8) | 'M'))
            {
                if (currentFrameData.size())
                {
                    //put frame to muxer
                    MediaFrame frame(MediaType::Video, MediaCodec::VideoH264);
                    frame.SetKeyFrame(frameNum % 100 == 0);
                    frame.SetPTS(frameNum++ * 0.04);
                    firstFrame = false;
                    avcc.ConvertToAnnexB(currentFrameData);
                    BitstreamWriter frameWriter = frame.GetDataWriter();
                    frameWriter.PutBytes(currentFrameData.cbegin(), currentFrameData.cend());
                    //std::cout << "Media frame " << frame.Data().size() << " bytes" << std::endl;
                    muxer.PutFrame(frame, videoTrack);
                    currentFrameData.clear();
                    writer.SetPosition(0);
                }
                if (reader.RemainingDataSize() > 4) last32Bits = uint32_t(reader.GetBits(32));
                else break;
            }
            else //shift-in one byte
            {
                uint8_t data = (last32Bits & 0xFF000000) >> 24;
                writer.PutByte(data);
                last32Bits = (last32Bits << 8) | reader.GetByte();
            }
        }

		return 0;
	}
	catch (std::exception& ex)
	{
		std::cout << ex.what() << std::endl;
		return 1;
	}
}

