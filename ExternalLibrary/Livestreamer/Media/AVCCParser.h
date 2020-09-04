#pragma once
#include "MediaBuffer.h"
#include "BitstreamReader.h"

class AVCCParser
{
private:
	std::vector<MediaBuffer> m_sps;
	std::vector<MediaBuffer> m_pps;

public:
	AVCCParser();
	virtual ~AVCCParser();

	void ExtractSpsPps(MediaBuffer& avccData);
    void ConvertToAnnexB(MediaBuffer& avccData);
	std::vector<MediaBuffer>& SPS();
	std::vector<MediaBuffer>& PPS();

	MediaBuffer GetDecoderConfigurationRecord();
	void ParseDecoderConfigurationRecord(BitstreamReader& reader);
};

