#pragma once
#include "IMultiTrackReceiver.h"
#include "MediaFrame.h"

template <class T>
class IMuxer: public IMultiTrackReceiver<T>
{
public:
	virtual ~IMuxer() = default;

	uint32_t AddTrack(MediaDescriptor descriptor) 
	{
		return AddTrackImpl(descriptor);
	};

private:
	virtual uint32_t AddTrackImpl(MediaDescriptor descriptor) = 0;
};

