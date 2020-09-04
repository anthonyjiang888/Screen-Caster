#pragma once
#include "IMultiTrackReceiver.h"
#include "IReceiver.h"
#include "MediaFrame.h"
#include "TSPacket.h"
#include <map>

class TSPacketizer: public IMultiTrackReceiver<MediaFrame>
{
public:
	TSPacketizer(IReceiverPtr<TSPacket> nextReceiver);
	virtual ~TSPacketizer();
	void SetPCRPid(uint32_t pcrPid);
	void PutPSISection(BitstreamReader& payload, uint32_t pid);

private:
	IReceiverPtr<TSPacket> m_nextReceiver;
	std::map<uint32_t, uint32_t> m_continuityCounters;
	uint32_t m_pcrPid;
    TSPacket m_result;
	
	uint32_t GetCC(uint32_t pid);
	void IncrementCC(uint32_t pid);
	TSPacket CreatePacket(uint32_t pid, BitstreamReader& payload, bool insertPCR, double dts, uint32_t cc, bool rapPoint);

	// Inherited via IMultiTrackReceiver
	virtual void PutFrameImpl(MediaFrame frame, uint32_t pid) override;
	virtual void CloseImpl() override;
};

