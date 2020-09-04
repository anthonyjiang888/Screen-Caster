#include "AVCCParser.h"
#include "BitstreamReader.h"
#include "BitstreamWriter.h"

enum class AVCNALUType: uint8_t
{
	SPS = 7,
	PPS = 8
};

AVCCParser::AVCCParser()
{
}


AVCCParser::~AVCCParser()
{
}

void AVCCParser::ExtractSpsPps(MediaBuffer & avccData)
{
	m_sps.clear();
	m_pps.clear();
	BitstreamReader reader(avccData);
	while (reader.RemainingDataSize() >= 4)
	{
		uint32_t nalUSize = uint32_t(reader.GetBits(32));
		if (!nalUSize) continue;
		if (reader.RemainingDataSize() < nalUSize) break;
		uint8_t nalUType = reader.GetByte();
		if ((nalUType & 0x1F) == uint8_t(AVCNALUType::PPS) ||
			(nalUType & 0x1F) == uint8_t(AVCNALUType::SPS))
		{
			MediaBuffer nalu(nalUSize);
			nalu[0] = nalUType;
			reader.GetBytes(nalu.begin() + 1, nalUSize - 1);
			(nalUType & 0x1F) == uint8_t(AVCNALUType::PPS) ? m_pps.push_back(std::move(nalu)) : m_sps.push_back(std::move(nalu));
		}
	}
}

void AVCCParser::ConvertToAnnexB(MediaBuffer & avccData)
{
    BitstreamReader reader(avccData);
    while (reader.RemainingDataSize() >= 4)
    {
        uint32_t nalUSize = uint32_t(reader.GetBits(32));
        avccData[reader.Position() - 4] = 0;
        avccData[reader.Position() - 3] = 0;
        avccData[reader.Position() - 2] = 0;
        avccData[reader.Position() - 1] = 1;
        if (!nalUSize) continue;
        if (reader.RemainingDataSize() < nalUSize) break;
        reader.Skip(nalUSize);
    }
}

std::vector<MediaBuffer>& AVCCParser::SPS()
{
	return m_sps;
}

std::vector<MediaBuffer>& AVCCParser::PPS()
{
	return m_pps;
}

MediaBuffer AVCCParser::GetDecoderConfigurationRecord()
{
	if (m_sps.size() == 0) throw std::runtime_error("no sps defined");
	MediaBuffer result;
	BitstreamWriter writer(result);
	writer.PutByte(0x01);				//Version
	writer.PutByte(m_sps[0][1]);		//Profile
	writer.PutByte(m_sps[0][2]);		//Compatibility
	writer.PutByte(m_sps[0][3]);		//Level
	writer.PutBits(0xFF, 6);			//reserved
	writer.PutBits(0x03, 2);			//nalu size field length minus 1

	writer.PutBits(0xFF, 3);			//reserved
	writer.PutBits(m_sps.size(), 5);	//sps count
	for (size_t i = 0; i < m_sps.size(); i++)
	{
		writer.PutBits(m_sps[i].size(), 16);					//sps length
		writer.PutBytes(m_sps[i].cbegin(), m_sps[i].cend());	//sps
	}

	writer.PutByte(uint8_t(m_pps.size()));		//pps count
	for (size_t i = 0; i < m_pps.size(); i++)
	{
		writer.PutBits(m_pps[i].size(), 16);					//pps length
		writer.PutBytes(m_pps[i].cbegin(), m_pps[i].cend());	//pps
	}

	return result;
}

void AVCCParser::ParseDecoderConfigurationRecord(BitstreamReader& reader)
{
	m_sps.clear();
	m_pps.clear();
	uint8_t version = reader.GetByte();	// Version
	if (version != 0x01) throw std::runtime_error("unknown avc decoder configuration version");
	reader.GetByte();					// Profile
	reader.GetByte();					// Compatibility
	reader.GetByte();					// Level
	reader.GetByte();					// reserved and NALu size
	reader.GetBits(3);					// reserved
	size_t spsCount = size_t(reader.GetBits(5));// sps count
	for (size_t i = 0; i < spsCount; i++)
	{
		size_t spsLength = size_t(reader.GetBits(16)); // sps length
		MediaBuffer sps(spsLength);
		reader.GetBytes(sps.begin(), spsLength); // sps
		m_sps.push_back(sps);
	}
	size_t ppsCount = size_t(reader.GetByte());	// pps count
	for (size_t i = 0; i < ppsCount; i++)
	{
		size_t ppsLength = size_t(reader.GetBits(16)); //pps length
		MediaBuffer pps(ppsLength);
		reader.GetBytes(pps.begin(), ppsLength); // pps
		m_pps.push_back(pps);
	}
}

