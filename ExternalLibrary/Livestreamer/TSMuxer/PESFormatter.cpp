#include "PESFormatter.h"



PESFormatter::PESFormatter(TSPacketizer& packetizer, TSTrackDescriptor descriptor):
	m_packetizer(packetizer),
	m_trackDescriptor(descriptor),
    m_result(descriptor.type, descriptor.codec)
{
}


PESFormatter::~PESFormatter()
{
}

void PESFormatter::PutFrameImpl(MediaFrame frame)
{
	//refactoring
    //MediaFrame m_result(frame.Descriptor().type, frame.Descriptor().codec);
	m_result.SetKeyFrame(frame.KeyFrame());
	m_result.SetPTS(frame.PTS());
	m_result.SetDTS(frame.DTS());
    m_result.Data().resize(0);
	BitstreamWriter bs = m_result.GetDataWriter();

	size_t pesHdrLength = 0;

	//pts
	TSPacket::PTSDTSFlags ptsDtsFlags = TSPacket::PTSDTSFlags::PtsOnly;
	pesHdrLength += 5;

	//dts
	if (frame.DTS() > 0.0 && frame.DTS() != frame.PTS())
	{
		ptsDtsFlags = TSPacket::PTSDTSFlags::PtsDts;
		pesHdrLength += 5;
	}

	size_t pesPacketLength = 0;
	pesPacketLength += 2; //flags
	pesPacketLength += 1; //pes hdr length field
	pesPacketLength += pesHdrLength; //pes hdr
	pesPacketLength += frame.Data().size(); //payload
	if (pesPacketLength > 65535) pesPacketLength = 0;

	bs.PutByte(0x00);
	bs.PutByte(0x00);
	bs.PutByte(0x01);
	bs.PutByte(uint8_t(m_trackDescriptor.type));            // stream_id
	bs.PutBits(pesPacketLength, 16);                        // PES_packet_length
	bs.PutByte(0x02 << 6);

	bs.PutByte(uint8_t(uint8_t(ptsDtsFlags) << 6));
	bs.PutByte(uint8_t(pesHdrLength));                  // PES_header_data_length

	if (ptsDtsFlags == TSPacket::PTSDTSFlags::PtsOnly || ptsDtsFlags == TSPacket::PTSDTSFlags::PtsDts)
	{
		uint64_t pts = uint64_t(frame.PTS() * 90000.0 + 0.5);
		bs.PutBits(uint32_t(ptsDtsFlags) & 3, 4);       // '0010' or '0011'
		bs.PutBits(uint32_t((pts >> 30) & 0x07), 3);    // PTS [32..30]
		bs.PutBits(0x01, 1);                            // marker_bit
		bs.PutBits(uint32_t((pts >> 15) & 0x7fff), 15); // PTS [29..15]
		bs.PutBits(0x01, 1);                            // marker_bit
		bs.PutBits(uint32_t(pts & 0x7fff), 15);         // PTS [14..0]
		bs.PutBits(0x01, 1);                            // marker_bit
	}
	if (ptsDtsFlags == TSPacket::PTSDTSFlags::PtsDts)
	{
		uint64_t dts = uint64_t(frame.PTS() * 90000.0 + 0.5);
		bs.PutBits(0x01, 4);                            // '0001'
		bs.PutBits(uint32_t((dts >> 30) & 0x07), 3);    // DTS [32..30]
		bs.PutBits(0x01, 1);                            // marker_bit
		bs.PutBits(uint32_t((dts >> 15) & 0x7fff), 15); // DTS [29..15]
		bs.PutBits(0x01, 1);                            // marker_bit
		bs.PutBits(uint32_t(dts & 0x7fff), 15);         // DTS [14..0]
		bs.PutBits(0x01, 1);                            // marker_bit
	}

	bs.PutBytes(frame.Data().cbegin(), frame.Data().cend());

	m_packetizer.PutFrame(m_result, m_trackDescriptor.pid);
}

void PESFormatter::CloseImpl()
{
}
