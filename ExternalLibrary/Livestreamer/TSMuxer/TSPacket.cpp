#include "TSPacket.h"


TSPacket::TSPacket() :
	p_impl(std::make_shared<TSPacketImpl>()),
	m_randomAccessPoint(false)
{
}


TSPacket::~TSPacket()
{
}

MediaBuffer& TSPacket::Data()
{
	return p_impl->data;
}

uint32_t TSPacket::Pid()
{
	return ((p_impl->data[1] & 0x1F) << 8) + p_impl->data[2];
}

bool TSPacket::ContainsPCR()
{
	return AdaptationFieldTotalSize() > 1 && (p_impl->data[5] & 0x10);
}

double TSPacket::PCR()
{
	if (!ContainsPCR()) return 0;
	uint64_t pcr_base = 0;
	pcr_base |= ((uint64_t)p_impl->data[6]) << 25;
	pcr_base |= ((uint64_t)p_impl->data[7]) << 17;
	pcr_base |= ((uint64_t)p_impl->data[8]) << 9;
	pcr_base |= ((uint64_t)p_impl->data[9]) << 1;
	pcr_base |= ((uint64_t)p_impl->data[10] & 0x80) >> 7;

	uint32_t pcr_ext = 0;
	pcr_ext |= ((uint32_t)p_impl->data[10] & 0x01) << 8;
	pcr_ext |= ((uint32_t)p_impl->data[11]);
	double pcr = (pcr_base * 300 + pcr_ext) / 27000000.0;
	return pcr;
}

void TSPacket::UpdatePCR(double pcrDts)
{
	uint64_t pcr = (uint64_t)(pcrDts * 27000000 + 0.5);
	uint64_t pcr_base = (pcr / 300) & 0x1FFFFFFFFU;
	uint32_t pcr_ext = (uint32_t)((pcr % 300) & 0x1FF);

	BitstreamWriter bs(p_impl->data);
	bs.SetPosition(6);

	bs.PutBits((pcr_base >> 32), 1);          // program_clock_reference_base[32..32]
	bs.PutBits((pcr_base & 0xFFFFFFFF), 32);  // program_clock_reference_base[31..0]
	bs.PutBits(0x3F, 6);                      // reserved
	bs.PutBits((pcr_ext), 9);                 // program_clock_reference_extension
}

bool TSPacket::PayloadStartMarker()
{
	return (p_impl->data[1] & 0x40) != 0;
}

bool TSPacket::AdaptationFieldExistsMarker()
{
	return (p_impl->data[3] & 0x20) != 0;
}

size_t TSPacket::AdaptationFieldTotalSize()
{
	if (AdaptationFieldExistsMarker())
	{
		return p_impl->data[4] + 1; //0..183 + 1 (size field included)
	}
	else
	{
		return 0;
	}
}

uint8_t TSPacket::CC()
{
	return p_impl->data[3] & 0x0F;
}

void TSPacket::UpdateCC(uint8_t cc)
{
	p_impl->data[3] = (p_impl->data[3] & 0xF0) | (cc & 0x0F);
}

void TSPacket::SetRAP(bool randomAccessPoint)
{
	m_randomAccessPoint = randomAccessPoint;
}

bool TSPacket::GetRAP()
{
	return m_randomAccessPoint;
}

void TSPacket::Validate()
{
	if (p_impl->data.size() != TSPacket::SIZE) throw std::runtime_error("wrong TS packet length");
	if (p_impl->data[0] != TSPacket::SYNC_BYTE) throw std::runtime_error("TS packet is out of sync. 0x47 marker was not found");
}

BitstreamReader TSPacket::GetReaderAndSeekToPayload()
{
	BitstreamReader result(p_impl->data);
	result.Skip(TSPacket::HEADER_SIZE + AdaptationFieldTotalSize());
	return result;
}

BitstreamWriter TSPacket::GetWriter()
{
	return BitstreamWriter(p_impl->data);
}

size_t TSPacket::GetPayloadSize()
{
	return TSPacket::SIZE - TSPacket::HEADER_SIZE - AdaptationFieldTotalSize();
}
