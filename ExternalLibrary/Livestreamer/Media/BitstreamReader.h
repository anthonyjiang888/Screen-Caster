#pragma once
#include "MediaBuffer.h"

class BitstreamReader
{
private:
	const MediaBuffer& m_sourceBuffer;
	MediaBuffer::const_iterator m_currentPosition;
	uint8_t m_currentByte;
	virtual uint8_t GetByteInternal();

protected:
	uint8_t m_validBits;

public:
	BitstreamReader(const MediaBuffer& sourceBuffer);
	virtual ~BitstreamReader();

	uint8_t GetByte();
	uint64_t GetBits(const uint8_t bitsCount);
	
	size_t Position();
	void SetPosition(size_t newPosition);
	void Skip(size_t bytesCount);
	size_t RemainingDataSize();

	template<class T>
	void GetBytes(T it, size_t count)
	{
		if (m_validBits) throw std::runtime_error("bitstream reader is not aligned");
		MediaBuffer::const_iterator end = (RemainingDataSize() <= count) ? m_sourceBuffer.cend() : (m_currentPosition + count);
		std::copy(m_currentPosition, end, it);
		SetPosition(Position() + count);
	}
};

