#pragma once
#include "TSProgramDescriptor.h"
#include "TSPacketizer.h"

class PATFormatter
{
public:
	PATFormatter(TSPacketizer& packetizer);
	virtual ~PATFormatter();
	void WritePAT(std::vector<TSProgramDescriptor>& programs);

private:
	TSPacketizer& m_packetizer;
};

