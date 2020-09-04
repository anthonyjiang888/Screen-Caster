#include "PMTFormatter.h"
#include "CRC32.h"


PMTFormatter::PMTFormatter(TSPacketizer& packetizer):
	m_packetizer(packetizer)
{
}


PMTFormatter::~PMTFormatter()
{
}

void PMTFormatter::WritePMT(TSProgramDescriptor program, std::vector<TSTrackDescriptor>& tracks)
{
	MediaBuffer buffer;
	BitstreamWriter bs(buffer);

	bs.PutBits(0x02, 8);                        // table_id
	bs.PutBits(0x01, 1);                        // section_syntax_indicator
	bs.PutBits(0x00, 1);                        // '0'
	bs.PutBits(0x03, 2);                        // reserved
	bs.PutBits(uint32_t(13 + 5 * tracks.size()), 12);    // section_length
	bs.PutBits(program.number, 16);             // program_number
	bs.PutBits(0x03, 2);                        // reserved
	bs.PutBits(0x00, 5);                        // version_number
	bs.PutBits(0x01, 1);                        // current_next_indicator
	bs.PutBits(0x00, 8);                        // section_number
	bs.PutBits(0x00, 8);                        // last_section_number
	bs.PutBits(0x07, 3);                        // reserved
	bs.PutBits(program.pcrPid, 13);             // PCR_PID
	bs.PutBits(0x0F, 4);                        // reserved
	bs.PutBits(0x00, 12);                       // program_info_length

	for (size_t i = 0; i < tracks.size(); i++)
	{
		TSTrackDescriptor track = tracks[i];
		bs.PutBits(uint32_t(track.codec), 8);    // stream_type
		bs.PutBits(0x07, 3);                     // reserved
		bs.PutBits(track.pid, 13);				 // elementary_PID
		bs.PutBits(0x0F, 4);                     // reserved
		bs.PutBits(0, 12);                       // ES_info_length
	}

	CRC32 crc32Calculator;
	uint32_t crc32 = crc32Calculator.Calculate(buffer.cbegin(), buffer.size());
	bs.PutBits(crc32, 32);                      // CRC_32

	BitstreamReader payload(buffer);
	m_packetizer.PutPSISection(payload, program.pid);
}
