#pragma once
#include "Enums.h"

struct MediaDescriptor
{
	MediaType type;
	MediaCodec codec;

	MediaDescriptor(MediaType _type, MediaCodec _codec)
	{
		type = _type;
		codec = _codec;
	}
};

