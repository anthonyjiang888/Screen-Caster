#pragma once
#include "TSPacketizer.h"
#include "TSTrackDescriptor.h"
#include "IReceiver.h"

class PESFormatter: public IReceiver<MediaFrame>
{
public:
	PESFormatter(TSPacketizer& packetizer, TSTrackDescriptor descriptor);
	virtual ~PESFormatter();

private:
	TSPacketizer& m_packetizer;
	TSTrackDescriptor m_trackDescriptor;
    MediaFrame m_result;


	// Inherited via IReceiver
	virtual void PutFrameImpl(MediaFrame frame) override;
	virtual void CloseImpl() override;
};

