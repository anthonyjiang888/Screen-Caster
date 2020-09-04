#include "TSMuxer.h"



TSMuxer::TSMuxer(IReceiverPtr<TSPacket> nextReceiver):
	m_tsPacketizer(nextReceiver),
	m_patFormatter(m_tsPacketizer),
	m_pmtFormatter(m_tsPacketizer),
    firstFrame(true)
{
	m_program.number = 100;
	m_program.pid = 100;
	m_program.pcrPid = 0;
}


TSMuxer::~TSMuxer()
{
}

void TSMuxer::GeneratePatPmt()
{
	std::vector<TSProgramDescriptor> programs = { m_program };
	m_patFormatter.WritePAT(programs);
	m_pmtFormatter.WritePMT(m_program, m_tracks);
}

void TSMuxer::PutFrameImpl(MediaFrame frame, uint32_t track)
{
	if (firstFrame)
	{
		firstFrame = false;
		GeneratePatPmt();
	}
	m_pesFormatters[track]->PutFrame(frame);
}

void TSMuxer::CloseImpl()
{
	m_tsPacketizer.Close();
}

uint32_t TSMuxer::AddTrackImpl(MediaDescriptor descriptor)
{
	TSTrackDescriptor track(m_tracks.size() + 38, descriptor.type, descriptor.codec);
	if (descriptor.type == MediaType::Video)
	{
		m_program.pcrPid = track.pid;
		m_tsPacketizer.SetPCRPid(m_program.pcrPid);
	}
	m_tracks.push_back(track);
	m_pesFormatters[track.pid] = std::make_shared<PESFormatter>(m_tsPacketizer, track);	
	return track.pid;
}
