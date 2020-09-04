#pragma once
#include "MediaFrame.h"

template<class T>
class IReceiver
{
public:
	void PutFrame(T frame) { PutFrameImpl(frame); };
	void Close() { CloseImpl(); };
	virtual ~IReceiver() = default;

private:

	virtual void PutFrameImpl(T frame) = 0;
	virtual void CloseImpl() = 0;
};

template <class T>
using IReceiverPtr = std::shared_ptr<IReceiver<T>>;