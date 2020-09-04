#include "PATFormatter.h"
#include "BitstreamReader.h"
#include "BitstreamWriter.h"
#include "MediaBuffer.h"
#include "CRC32.h"

PATFormatter::PATFormatter(TSPacketizer& packetizer):
	m_packetizer(packetizer)
{
}


PATFormatter::~PATFormatter()
{
}

void PATFormatter::WritePAT(std::vector<TSProgramDescriptor>& programs)
{
	MediaBuffer buffer;
	BitstreamWriter bs(buffer);

	bs.PutBits(0x00, 8);                        // table_id
	bs.PutBits(0x01, 1);                        // section_syntax_indicator
	bs.PutBits(0x00, 1);                        // '0'
	bs.PutBits(0x03, 2);                        // reserved
	bs.PutBits(uint32_t(4 * programs.size() + 9), 12);    // section_length
	bs.PutBits(0x01, 16);				        // transport_stream_id
	bs.PutBits(0x03, 2);                        // reserved
	bs.PutBits(0x00, 5);                        // version_number
	bs.PutBits(0x01, 1);                        // current_next_indicator
	bs.PutBits(0x00, 8);                        // section_number
	bs.PutBits(0x00, 8);                        // last_section_number

	for (size_t i = 0; i < programs.size(); i++)
	{
		bs.PutBits(programs[i].number, 16);     // program_number
		bs.PutBits(0x07, 3);                    // reserved
		bs.PutBits(programs[i].pid, 13);        // program_map_PID
	}


	CRC32 crc32Calculator;
	uint32_t crc32 = crc32Calculator.Calculate(buffer.cbegin(), buffer.size());
	bs.PutBits(crc32, 32);                      // CRC_32

	BitstreamReader payload(buffer);
	m_packetizer.PutPSISection(payload, 0x00);
}
