#include "HLSPlaylistBuilder.h"
#include <fstream>
#include <iomanip>

HLSPlaylistBuilder::HLSPlaylistBuilder(std::string path, int32_t windowLength):
	m_path(path),
	m_windowLength(windowLength)
{
}


HLSPlaylistBuilder::~HLSPlaylistBuilder()
{
}

void HLSPlaylistBuilder::Render()
{
	std::ofstream output(m_path, std::ofstream::binary);
	output << "#EXTM3U" << std::endl;
	output << "#EXT-X-VERSION:3" << std::endl;
	output << "#EXT-X-TARGETDURATION:5" << std::endl;
	int32_t firstIndex = int32_t(m_entries.size()) - m_windowLength;
	if (firstIndex < 0) firstIndex = 0;
	for (size_t i = size_t(firstIndex); i < m_entries.size(); i++)
	{
		HLSPlaylistEntry& entry = m_entries[i];
		if (i == size_t(firstIndex))
		{
			output << "#EXT-X-MEDIA-SEQUENCE:" << entry.index << std::endl;
		}
		output << "#EXTINF:" << std::setprecision(2) << entry.duration << ", no-desc" << std::endl;
		output << entry.path << std::endl;
	}
}

void HLSPlaylistBuilder::PutFrameImpl(HLSPlaylistEntry frame)
{
	m_entries.push_back(frame);
    while(m_entries.size() > m_windowLength * 3)
    {
        if(toBeRemoved != nullptr) toBeRemoved(m_entries[0]);
        m_entries.erase(m_entries.begin());
    }
}

void HLSPlaylistBuilder::CloseImpl()
{
}
