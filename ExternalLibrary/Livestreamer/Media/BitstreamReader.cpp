#include "BitstreamReader.h"



BitstreamReader::BitstreamReader(const MediaBuffer& sourceBuffer):
	m_sourceBuffer(sourceBuffer),
	m_currentPosition(sourceBuffer.cbegin()),
	m_currentByte(0),
	m_validBits(0)
{
}


BitstreamReader::~BitstreamReader()
{
}

uint8_t BitstreamReader::GetByteInternal()
{
	uint8_t result = 0;
	if (m_currentPosition != m_sourceBuffer.cend())
	{
		result = *m_currentPosition;
		++m_currentPosition;
	}
	return result;
}

uint8_t BitstreamReader::GetByte()
{
	if (m_validBits) throw std::runtime_error("bitstream reader is not aligned");
	return GetByteInternal();
}

uint64_t BitstreamReader::GetBits(const uint8_t bitsCount)
{
	uint64_t result = 0;
	uint8_t remainingBits = bitsCount;
	while (remainingBits > 0)
	{
		if (m_validBits == 0)
		{
			m_currentByte = GetByteInternal();
			m_validBits = 8;
		}
		uint8_t bitsToBeRead = remainingBits < m_validBits ? remainingBits : m_validBits;
		uint8_t sourceMask = (1 << m_validBits) - 1;
		uint64_t readData = uint64_t(m_currentByte & sourceMask) >> (m_validBits - bitsToBeRead);
		result |= readData << (remainingBits - bitsToBeRead);
		remainingBits -= bitsToBeRead;
		m_validBits -= bitsToBeRead;
	}
	return result;
}

size_t BitstreamReader::Position()
{
	return (m_currentPosition == m_sourceBuffer.end()) ? m_sourceBuffer.size() : (m_currentPosition - m_sourceBuffer.begin());
}

void BitstreamReader::SetPosition(size_t newPosition)
{
	m_currentPosition = (newPosition >= m_sourceBuffer.size()) ? m_sourceBuffer.end() : (m_sourceBuffer.begin() + newPosition);
}

void BitstreamReader::Skip(size_t bytesCount)
{
	SetPosition(Position() + bytesCount);
}

size_t BitstreamReader::RemainingDataSize()
{
	return m_sourceBuffer.size() - Position();
}
