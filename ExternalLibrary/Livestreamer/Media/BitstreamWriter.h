#pragma once
#include "MediaBuffer.h"

class BitstreamWriter
{
private:
	MediaBuffer& m_buffer;
	MediaBuffer::iterator m_currentPosition;
	uint8_t m_currentByte;
	virtual void PutByteInternal(const uint8_t byte);

protected:
	uint8_t m_validBitsCount;

public:
	BitstreamWriter(MediaBuffer& destinationBuffer);
	virtual ~BitstreamWriter();

	void PutByte(const uint8_t byte);
	void PutBits(const uint64_t data, const uint8_t bitsCount);

	size_t Position();
	void SetPosition(size_t newPosition);
	void SeekToEnd();

	template<class T>
	void PutBytes(T begin, T end)
	{
		if (m_validBitsCount) throw std::runtime_error("bitstream writer is not aligned");
		size_t position = Position();
		size_t count = end - begin;
		size_t newSize = position + count;
		if (newSize > m_buffer.size())
		{
			m_buffer.resize(newSize);
			SetPosition(position);
		}
		std::copy(begin, end, m_currentPosition);
		SetPosition(Position() + count);
	}
};

