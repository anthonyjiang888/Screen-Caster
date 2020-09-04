#pragma once
#include "BitstreamReader.h"
#include "NetworkConnection.h"
#include <algorithm>
#include <array>
#include <unistd.h>

class NetworkBitstreamReader: BitstreamReader
{
public:
	NetworkBitstreamReader(NetworkConnection& connection):
		BitstreamReader(MediaBuffer()),
		m_connection(connection)
	{
	}

	using BitstreamReader::GetByte;
	using BitstreamReader::GetBits;

	template<class T>
	void GetBytes(T it, size_t count)
	{
		if (m_validBits) throw std::runtime_error("bitstream reader is not aligned");
		const size_t buffSize = 1024;
		std::array<uint8_t, buffSize> buffer;
		while (count > 0)
		{
			size_t dataSize = std::min(count, buffSize);
			m_connection.Receive(&buffer, dataSize);
			std::copy(std::begin(buffer), std::begin(buffer) + dataSize, it);
			it += dataSize;
			count -= dataSize;
		}
	}


private:
	NetworkConnection& m_connection;

	virtual uint8_t GetByteInternal() override
	{
		uint8_t data;
        int attempt = 0;
        
		while(!m_connection.Receive(&data, sizeof(data)))
        {
            if(attempt==10) throw std::runtime_error("no data received");
            sleep(100);
            attempt++;
        }
		return data;
	}
};
