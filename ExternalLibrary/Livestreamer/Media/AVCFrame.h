#pragma once
#include "MediaFrame.h"

class AVCFrame : public MediaFrame
{
private:
	struct AVCFrameImplementation
	{
		std::vector<MediaBuffer> sps;
		std::vector<MediaBuffer> pps;
	};
	std::shared_ptr<AVCFrameImplementation> p_impl;

public:
	AVCFrame();
	virtual ~AVCFrame();

	void SetSPS(std::vector<MediaBuffer>& sps);
	void SetPPS(std::vector<MediaBuffer>& pps);
	std::vector<MediaBuffer>& SPS();
	std::vector<MediaBuffer>& PPS();
};

