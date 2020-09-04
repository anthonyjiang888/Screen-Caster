#include "BitstreamWriter.h"



BitstreamWriter::BitstreamWriter(MediaBuffer& destinationBuffer):
	m_buffer(destinationBuffer),
	m_currentPosition(destinationBuffer.begin()),
	m_currentByte(0),
	m_validBitsCount(0)
{
}


BitstreamWriter::~BitstreamWriter()
{
}

void BitstreamWriter::PutByteInternal(const uint8_t byte)
{
	//add new element
	if (m_currentPosition == m_buffer.end())
	{
		m_buffer.push_back(byte);
		m_currentPosition = m_buffer.end();
	}
	else //replace
	{
		*m_currentPosition = byte;
		++m_currentPosition;
	}
}

void BitstreamWriter::PutByte(const uint8_t byte)
{
	if (m_validBitsCount) throw std::runtime_error("bitstream writer is not aligned");
	PutByteInternal(byte);
}

void BitstreamWriter::PutBits(const uint64_t data, const uint8_t bitsCount)
{
	uint8_t remainingBits = bitsCount;
	while (remainingBits > 0)
	{
		uint8_t bitsToBeWritten = 8 - m_validBitsCount;
		if (bitsToBeWritten > remainingBits) bitsToBeWritten = remainingBits;
		uint64_t mask = (uint64_t(1) << bitsCount) - 1;
		uint64_t dataToBeWritten = (data & mask) >> (remainingBits - bitsToBeWritten);
		m_currentByte |= dataToBeWritten << (8 - m_validBitsCount - bitsToBeWritten);
		m_validBitsCount += bitsToBeWritten;
		remainingBits -= bitsToBeWritten;
		if (m_validBitsCount == 8)
		{
			PutByteInternal(m_currentByte);
			m_currentByte = 0;
			m_validBitsCount = 0;
		}
	}
}

size_t BitstreamWriter::Position()
{
	return (m_currentPosition == m_buffer.end()) ? m_buffer.size() : (m_currentPosition - m_buffer.begin());
}

void BitstreamWriter::SetPosition(size_t newPosition)
{
	m_currentPosition = (newPosition >= m_buffer.size()) ? m_buffer.end() : (m_buffer.begin() + newPosition);
}

void BitstreamWriter::SeekToEnd()
{
	m_currentPosition = m_buffer.end();
}
