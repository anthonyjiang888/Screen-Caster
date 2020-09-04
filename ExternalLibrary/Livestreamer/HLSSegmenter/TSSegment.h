#pragma once
#include "IReceiver.h"
#include "TSPacket.h"
#include <string>
#include <fstream>

class TSSegment: public IReceiver<TSPacket>
{
public:
	TSSegment();
    TSSegment(std::string directory, std::string path, int32_t index);
	virtual ~TSSegment();
	bool IsEmpty() const;
    void Render(std::string directory) const;
    void Remove(std::string directory) const;
	std::string Path() const;
	int32_t GetIndex() const;
    void SetPath(std::string path);
    void SetIndex(int32_t index);
    void ResetData();

private:
	struct TSSegmentImpl
	{
		MediaBuffer data;
		BitstreamWriter writer;
        size_t dataWritten;
        std::shared_ptr<std::ofstream> output;
        TSSegmentImpl(std::string path) :
			writer(data),
            dataWritten(0)
		{
            if(!path.empty()) output = std::make_shared<std::ofstream>(path);
		}
	};
	std::shared_ptr<TSSegmentImpl> p_impl;
	std::string m_path;
	int32_t m_index;
	
    // Inherited via IReceiver
	virtual void PutFrameImpl(TSPacket frame) override;
	virtual void CloseImpl() override;

};

