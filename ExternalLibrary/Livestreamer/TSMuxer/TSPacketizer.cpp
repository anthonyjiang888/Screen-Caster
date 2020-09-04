#include "TSPacketizer.h"
#include <algorithm>


TSPacketizer::TSPacketizer(IReceiverPtr<TSPacket> nextReceiver):
	m_nextReceiver(nextReceiver)
{
}


TSPacketizer::~TSPacketizer()
{
}

void TSPacketizer::SetPCRPid(uint32_t pcrPid)
{
	m_pcrPid = pcrPid;
}

void TSPacketizer::PutPSISection(BitstreamReader& sourceStream, uint32_t pid)
{
	int packetIndex = 0;
	while (sourceStream.RemainingDataSize() > 0)
	{
		IncrementCC(pid);

        TSPacket m_result;
		for (size_t i = 0; i < TSPacket::SIZE; i++) m_result.Data()[i] = 0xFF; //PSI stuffing
		BitstreamWriter bs = m_result.GetWriter();

		bs.PutByte(0x47);											// sync_byte
		bs.PutBits(0x00, 1);                                        // transport_error_indicator
		bs.PutBits((sourceStream.Position() == 0 ? 0x01U : 0x00U), 1);  // payload_unit_start_indicator
		bs.PutBits(0x00, 1);                                        // transport_priority
		bs.PutBits(pid, 13);                                        // PID
		bs.PutBits(0x00, 2);                                        // transport_scrambling_control
		bs.PutBits(0x01, 2);                                        // adaptation_field_control
		bs.PutBits(GetCC(pid), 4);                                  // continuity_counter
		if (sourceStream.Position() == 0)
		{
			bs.PutByte(0x00);										// pointer_field
		}
		while (bs.Position() < TSPacket::SIZE && sourceStream.RemainingDataSize() > 0)
		{
			bs.PutByte(sourceStream.GetByte());
		}

		m_nextReceiver->PutFrame(m_result);
		packetIndex++;
	}
}

uint32_t TSPacketizer::GetCC(uint32_t pid)
{
	return m_continuityCounters[pid];
}

void TSPacketizer::IncrementCC(uint32_t pid)
{
	uint32_t newCC = (GetCC(pid) + 1) & 0x0f;
	m_continuityCounters[pid] = newCC;
}

TSPacket TSPacketizer::CreatePacket(uint32_t pid, BitstreamReader& payload, bool insertPCR, double dts, uint32_t cc, bool rapPoint)
{
    //TSPacket m_result;
	m_result.SetRAP(rapPoint);

	BitstreamWriter bs = m_result.GetWriter();

	size_t availableSourcePayload = payload.RemainingDataSize();

	size_t maximumPayload = 184;
	TSPacket::AdaptationFieldFlags adaptationFlags = availableSourcePayload > 0 ? TSPacket::AdaptationFieldFlags::Payload : TSPacket::AdaptationFieldFlags::AdaptationField;
	size_t adaptationFieldLength = 0;
	size_t numberOfStuffingBytes = 0;

	if (insertPCR)
	{
		adaptationFlags = TSPacket::AdaptationFieldFlags(uint32_t(adaptationFlags) | uint32_t(TSPacket::AdaptationFieldFlags::AdaptationField));
		adaptationFieldLength += 7;
		maximumPayload -= 8;
	}

	if (maximumPayload > availableSourcePayload)
	{

		//adaptation field already enabled
		if ((uint32_t(adaptationFlags) & uint32_t(TSPacket::AdaptationFieldFlags::AdaptationField)))
		{
			numberOfStuffingBytes += (maximumPayload - availableSourcePayload);
			maximumPayload -= numberOfStuffingBytes;
			adaptationFieldLength += numberOfStuffingBytes;
		}
		else
		{
			//add adaptation field
			adaptationFlags = TSPacket::AdaptationFieldFlags((uint32_t)adaptationFlags | (uint32_t)TSPacket::AdaptationFieldFlags::AdaptationField);
			adaptationFieldLength = (maximumPayload - availableSourcePayload - 1);
			if (adaptationFieldLength > 0)
				numberOfStuffingBytes = (adaptationFieldLength - 1);
			maximumPayload -= (adaptationFieldLength + 1);
		}
	}

	bs.PutByte(0x47);                    // sync_byte
	bs.PutBits(pid | ((payload.Position() == 0) ? (0x01U << 14) : 0x00U), 16);
	bs.PutByte(uint8_t(uint8_t(adaptationFlags) << 4 | uint8_t(cc)));

	if (uint32_t(adaptationFlags) & uint32_t(TSPacket::AdaptationFieldFlags::AdaptationField))
	{
		bs.PutByte(uint8_t(adaptationFieldLength));   // adaptation_field_length

		if (adaptationFieldLength > 0)
		{
			bs.PutByte(uint8_t((rapPoint ? 0x01 << 6 : 0x00) | (insertPCR ? 0x01 << 4 : 0x00)));

			if (insertPCR)
			{
				uint64_t pcr = uint64_t(dts * 27000000 + 0.5);
				uint64_t pcr_base = (pcr / 300) & 0x1FFFFFFFFU;
				uint32_t pcr_ext = uint32_t((pcr % 300) & 0x1FF);

				bs.PutBits(uint32_t(pcr_base >> 32), 1);         // program_clock_reference_base[32..32]
				bs.PutBits(uint32_t(pcr_base & 0xFFFFFFFF), 32); // program_clock_reference_base[31..0]
				bs.PutBits(0x3F, 6);                             // reserved
				bs.PutBits(pcr_ext, 9);                        // program_clock_reference_extension
			}

			for (size_t i = 0; i < numberOfStuffingBytes; i++)
			{
				bs.PutByte(0xFF);
			}
		}
	}
	if (maximumPayload > 0)
	{
		size_t dataSize = std::min(maximumPayload, payload.RemainingDataSize());

		payload.GetBytes(m_result.Data().begin() + bs.Position(), dataSize);
		bs.SetPosition(bs.Position() + dataSize);
	}

	if (bs.Position() != TSPacket::SIZE)
	{
		throw std::runtime_error("wrong ts packet length");
	}
	return m_result;
}

void TSPacketizer::PutFrameImpl(MediaFrame frame, uint32_t pid)
{
	BitstreamReader sourceStream = frame.GetDataReader();

	int packetIndexInFrame = 0;

	while (sourceStream.RemainingDataSize() > 0)
	{
		bool addPCR = packetIndexInFrame == 0 && m_pcrPid == pid;
		TSPacket packet = CreatePacket(pid, sourceStream, addPCR, frame.PTS(), GetCC(pid), packetIndexInFrame == 0 && frame.KeyFrame());
		m_nextReceiver->PutFrame(packet);
		IncrementCC(pid);
		packetIndexInFrame++;
	}
}

void TSPacketizer::CloseImpl()
{
}

