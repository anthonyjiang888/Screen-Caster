#pragma once
#include "TSTrackDescriptor.h"
#include "TSPacketizer.h"
#include "TSProgramDescriptor.h"

class PMTFormatter
{
public:
	PMTFormatter(TSPacketizer& packetizer);
	virtual ~PMTFormatter();
	void WritePMT(TSProgramDescriptor program, std::vector<TSTrackDescriptor>& tracks);

private:
	TSPacketizer& m_packetizer;
};

