#pragma once
#include <vector>

enum class MediaType: uint32_t
{
	Unknown,
    Video = 0xE0,
    Audio = 0xC0
};

enum class MediaCodec : uint32_t
{
	Unknown,
    VideoH264 = 0x1B,
    AudioAAC = 0x0F
};
