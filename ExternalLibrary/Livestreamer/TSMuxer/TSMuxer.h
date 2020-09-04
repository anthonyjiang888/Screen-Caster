#pragma once
#include "IMuxer.h"
#include "MediaFrame.h"
#include "TSPacketizer.h"
#include "PATFormatter.h"
#include "PMTFormatter.h"
#include "PESFormatter.h"
#include <vector>
#include <map>

class TSMuxer: public IMuxer<MediaFrame>
{
public:
	TSMuxer(IReceiverPtr<TSPacket> nextReceiver);
	virtual ~TSMuxer();

private:
	PATFormatter m_patFormatter;
	PMTFormatter m_pmtFormatter;
	std::map<uint32_t, IReceiverPtr<MediaFrame>> m_pesFormatters;
	TSProgramDescriptor m_program;
	std::vector<TSTrackDescriptor> m_tracks;
	TSPacketizer m_tsPacketizer;
	bool firstFrame;

	void GeneratePatPmt();

	// Inherited via IMuxer
	virtual void PutFrameImpl(MediaFrame frame, uint32_t track) override;
	virtual void CloseImpl() override;
	virtual uint32_t AddTrackImpl(MediaDescriptor descriptor) override;
};

