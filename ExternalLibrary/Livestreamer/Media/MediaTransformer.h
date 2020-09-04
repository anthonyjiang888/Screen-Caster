#pragma once
#include "IReceiver.h"

template<class InputType, class OutputType>
class MediaTransformer: public IReceiver<InputType>
{
public:
	MediaTransformer(IReceiverPtr<OutputType> nextReceiver):
		m_nextReceiver(nextReceiver),
		m_lastTransformResult(MediaTransformResult::Done)
	{
	}

protected:
	enum class MediaTransformResult
	{
		Done,
		MoreInput,
		MoreOutput
	};

private:
	IReceiverPtr<OutputType> m_nextReceiver;

	virtual OutputType CreateOutputFrame(InputType inputFrame) = 0;
	virtual MediaTransformResult Transform(InputType inputFrame, OutputType outputFrame) = 0;
	
	MediaTransformResult m_lastTransformResult;
	OutputType m_currentOutput;

	void PutFrameImpl(InputType inputFrame) override
	{
		do
		{
			if (m_lastTransformResult == MediaTransformResult::Done ||
				m_lastTransformResult == MediaTransformResult::MoreOutput)
			{
				m_currentOutput = CreateOutputFrame(inputFrame);
			}
			m_lastTransformResult = Transform(inputFrame, m_currentOutput);
			if (m_lastTransformResult == MediaTransformResult::Done ||
				m_lastTransformResult == MediaTransformResult::MoreOutput)
			{
				if(m_nextReceiver) m_nextReceiver->PutFrame(m_currentOutput);
			}
		} while (m_lastTransformResult == MediaTransformResult::MoreOutput);
	}

	void CloseImpl() override
	{
		if(m_nextReceiver) m_nextReceiver->Close();
	}
};