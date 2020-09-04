#include "AVCFrame.h"



AVCFrame::AVCFrame() :
	MediaFrame(MediaType::Video, MediaCodec::VideoH264),
	p_impl(std::make_shared<AVCFrameImplementation>())
{
}


AVCFrame::~AVCFrame()
{
}

void AVCFrame::SetSPS(std::vector<MediaBuffer>& sps)
{
	p_impl->sps = sps;
}

void AVCFrame::SetPPS(std::vector<MediaBuffer>& pps)
{
	p_impl->pps = pps;
}

std::vector<MediaBuffer>& AVCFrame::SPS()
{
	return p_impl->sps;
}

std::vector<MediaBuffer>& AVCFrame::PPS()
{
	return p_impl->pps;
}
