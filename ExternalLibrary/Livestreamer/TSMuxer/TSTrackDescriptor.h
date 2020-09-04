#pragma once
#include "MediaDescriptor.h"

struct TSTrackDescriptor : public MediaDescriptor
{
	uint32_t pid;
	TSTrackDescriptor(uint32_t _pid, MediaType _type, MediaCodec _codec) :
		MediaDescriptor(_type, _codec),
		pid(_pid)
	{

	}
};