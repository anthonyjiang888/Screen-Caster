#pragma once
#include "TSSegment.h"
#include "MediaTransformer.h"
#include <string>
#include "HLSPlaylistBuilder.h"

class HLSSegmenter: public MediaTransformer<TSPacket, TSSegment>
{
public:
    HLSSegmenter(IReceiverPtr<TSSegment> nextReceiver, std::string directory);
	virtual ~HLSSegmenter();

private:
	uint32_t m_pmtPid;
	TSPacket m_patPacket;
	TSPacket m_pmtPacket;
	int32_t m_segmentIndex;
    double m_lastRapPTS;
    TSSegment m_result;
    std::string m_directory;

	// Inherited via MediaTransformer
	virtual TSSegment CreateOutputFrame(TSPacket inputFrame) override;
	virtual MediaTransformResult Transform(TSPacket inputFrame, TSSegment outputFrame) override;
};

