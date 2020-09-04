#pragma once
#include "MediaFrame.h"

template<class T>
class IMultiTrackReceiver
{
public:
	void PutFrame(T frame, uint32_t track) { PutFrameImpl(frame, track); };
	void Close() { CloseImpl(); };
	virtual ~IMultiTrackReceiver() = default;

private:

	virtual void PutFrameImpl(T frame, uint32_t track) = 0;
	virtual void CloseImpl() = 0;
};

template<class T>
using IMultuTrackReceiverPtr = std::shared_ptr<IMultiTrackReceiver<T>>;
