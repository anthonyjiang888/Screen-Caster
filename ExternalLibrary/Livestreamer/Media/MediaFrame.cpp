#include "MediaFrame.h"



MediaFrame::MediaFrame(MediaType type, MediaCodec codec):
	p_impl(std::make_shared<MediaFrame::MediaFrameImplementation>(type, codec))
{
}


MediaFrame::~MediaFrame()
{
}

MediaBuffer & MediaFrame::Data()
{
	return p_impl->data;
}

MediaDescriptor & MediaFrame::Descriptor()
{
	return p_impl->descriptor;
}

double MediaFrame::PTS()
{
	return p_impl->m_pts;
}

void MediaFrame::SetPTS(double pts)
{
    p_impl->m_pts = pts;
    p_impl->m_dts = pts;
}

double MediaFrame::DTS()
{
    return p_impl->m_dts;
}

void MediaFrame::SetDTS(double dts)
{
    p_impl->m_dts = dts;
}

bool MediaFrame::KeyFrame()
{
	return p_impl->m_keyFrame;
}

void MediaFrame::SetKeyFrame(bool keyFrame)
{
	p_impl->m_keyFrame = keyFrame;
}

BitstreamReader MediaFrame::GetDataReader()
{
	return BitstreamReader(Data());
}

BitstreamWriter MediaFrame::GetDataWriter()
{
	return BitstreamWriter(Data());
}
