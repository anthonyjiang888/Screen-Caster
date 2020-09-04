#pragma once
#include "BitstreamWriter.h"
#include "NetworkConnection.h"
#include <array>
#include "MediaBuffer.h"

class NetworkBitstreamWriter : BitstreamWriter
{
public:
	NetworkBitstreamWriter(NetworkConnection& connection):
        m_placeholderBuffer(),
		m_connection(connection),
        BitstreamWriter(m_placeholderBuffer)
	{
	}

	using BitstreamWriter::PutBits;
	using BitstreamWriter::PutByte;

	template<class T>
	void PutBytes(T begin, T end)
	{
		if (m_validBitsCount) throw std::runtime_error("bitstream writer is not aligned");
		const size_t buffSize = 1024;
		std::array<uint8_t, buffSize> buffer;
		size_t distance;
		while ((distance = std::distance(begin, end)) > 0)
		{
			if (distance > buffSize) distance = buffSize;
			std::copy(begin, begin + distance, std::begin(buffer));
			m_connection.Send(&buffer, distance);
			begin += distance;
		}
	}

private:
	NetworkConnection& m_connection;
    MediaBuffer m_placeholderBuffer;

	virtual void PutByteInternal(const uint8_t byte) override
	{
		uint8_t data = byte;
		m_connection.Send(&data, sizeof(data));
	}
};
