#pragma once
#include "IReceiver.h"
#include <functional>

template <class T>
class MediaCallback: public IReceiver<T>
{
public:
	MediaCallback(std::function<void(T frame)> callback) :
		m_callback(callback)
	{
	}

	virtual ~MediaCallback() = default;

private:
	std::function<void(T frame)> m_callback;

	virtual void PutFrameImpl(T frame) 
	{
		if (m_callback) m_callback(frame);
	}
	virtual void CloseImpl() {};
};
