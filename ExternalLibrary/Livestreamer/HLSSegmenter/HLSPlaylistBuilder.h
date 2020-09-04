#pragma once
#include "IReceiver.h"
#include <queue>
#include <deque>
#include <string>

struct HLSPlaylistEntry
{
	std::string path;
	double duration;
	int32_t index;

	HLSPlaylistEntry(std::string _path, double _duration, int32_t _index):
		path(_path),
		duration(_duration),
		index(_index)
	{
	}
};

class HLSPlaylistBuilder: public IReceiver<HLSPlaylistEntry>
{
public:
    std::function<void(HLSPlaylistEntry)> toBeRemoved;
    
	HLSPlaylistBuilder(std::string path, int32_t windowLength);
	virtual ~HLSPlaylistBuilder();
	void Render();

private:
	std::vector<HLSPlaylistEntry> m_entries;
	std::string m_path;
	int32_t m_windowLength;

	// Inherited via IReceiver
	virtual void PutFrameImpl(HLSPlaylistEntry frame) override;
	virtual void CloseImpl() override;
};

