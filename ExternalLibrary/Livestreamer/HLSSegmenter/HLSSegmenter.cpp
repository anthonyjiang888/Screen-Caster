#include "HLSSegmenter.h"



HLSSegmenter::HLSSegmenter(IReceiverPtr<TSSegment> nextReceiver, std::string directory):
	MediaTransformer(nextReceiver),
	m_pmtPid(100),
	m_segmentIndex(0),
    m_lastRapPTS(0),
    m_directory(directory)
{
}


HLSSegmenter::~HLSSegmenter()
{
}

TSSegment HLSSegmenter::CreateOutputFrame(TSPacket inputFrame)
{
	m_segmentIndex++;
    return TSSegment(m_directory, "segment_" + std::to_string(m_segmentIndex) + ".ts", m_segmentIndex);
//    m_result.SetPath("segment_" + std::to_string(m_segmentIndex) + ".ts");
//    m_result.SetIndex(m_segmentIndex);
//    m_result.ResetData();
    //return m_result;
}

HLSSegmenter::MediaTransformResult HLSSegmenter::Transform(TSPacket inputFrame, TSSegment outputFrame)
{
	if (inputFrame.Pid() == 0x00) //PAT
	{
		m_patPacket = inputFrame;
	}
	else if (inputFrame.Pid() == m_pmtPid) //PMT
	{
		m_pmtPacket = inputFrame;
	}
	else
	{
        if (inputFrame.GetRAP() && (outputFrame.Path().empty() || !outputFrame.IsEmpty())) return MediaTransformResult::MoreOutput;
		if (outputFrame.IsEmpty())
		{
			outputFrame.PutFrame(m_patPacket);
			outputFrame.PutFrame(m_pmtPacket);
            m_patPacket.UpdateCC(m_patPacket.CC() + 1);
            m_pmtPacket.UpdateCC(m_pmtPacket.CC() + 1);
		}
		outputFrame.PutFrame(inputFrame);
	}
	return MediaTransformResult::MoreInput;
}
