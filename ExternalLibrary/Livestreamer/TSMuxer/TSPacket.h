#pragma once
#include <memory>
#include "MediaBuffer.h"
#include "BitstreamReader.h"
#include "BitstreamWriter.h"

class TSPacket
{
public:
	enum class PTSDTSFlags: uint32_t
	{
		PtsOnly = 0x02,
		PtsDts = 0x03,
		Nothing = 0x00
	};

	enum class AdaptationFieldFlags: uint32_t
	{
		Payload = 0x01,
		AdaptationField = 0x02,
		AdaptationPayload = 0x03,
	};


	static const size_t SIZE = 188;
	static const size_t HEADER_SIZE = 4;
	static const uint8_t SYNC_BYTE = 0x47;

	TSPacket();
	template<class T> TSPacket(T begin) : TSPacket()
	{
		std::copy(begin, begin + TSPacket::SIZE, p_impl->data.begin());
	}

	virtual ~TSPacket();

	MediaBuffer& Data();

	uint32_t Pid();
	bool ContainsPCR();
	double PCR();
	void UpdatePCR(double pcr);
	bool PayloadStartMarker();
	bool AdaptationFieldExistsMarker();
	size_t AdaptationFieldTotalSize();
	uint8_t CC();
	void UpdateCC(uint8_t cc);
	void SetRAP(bool randomAccessPoint);
	bool GetRAP();
	void Validate();

	BitstreamReader GetReaderAndSeekToPayload();
	BitstreamWriter GetWriter();

	template<class T> size_t GetPayload(T outIt)
	{
		size_t headersSize = TSPacket::HEADER_SIZE + AdaptationFieldTotalSize();
		size_t payloadSize = TSPacket::SIZE - headersSize;
		std::copy(p_impl->data.begin() + headersSize, p_impl->data.end(), outIt);
		return payloadSize;
	}

	size_t GetPayloadSize();

private:
	struct TSPacketImpl
	{
		MediaBuffer data;
		TSPacketImpl() :
			data(TSPacket::SIZE)
		{}
	};
	bool m_randomAccessPoint;
	std::shared_ptr<TSPacketImpl> p_impl;
};

