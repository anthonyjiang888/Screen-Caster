#include "TSSegment.h"
#include <iostream>
//#include <fstream>
#include <iterator>


TSSegment::TSSegment(std::string directory, std::string path, int32_t index):
	p_impl(std::make_shared<TSSegmentImpl>(directory + path)),
	m_path(path),
	m_index(index)
{
}

TSSegment::TSSegment() : TSSegment("", "", 0)
{
}


TSSegment::~TSSegment()
{
}

bool TSSegment::IsEmpty() const
{
	//return p_impl->data.empty();
    if(p_impl && p_impl->output) {
        return p_impl->dataWritten == 0;
    }
    else return true;
}

void TSSegment::SetPath(std::string path) {
    m_path = path;
}

void TSSegment::SetIndex(int32_t index) {
    m_index = index;
}

void TSSegment::ResetData() {
    if(p_impl && p_impl->output) {
        p_impl->data.resize(0);
        p_impl->dataWritten = 0;
    }
}

void TSSegment::Render(std::string directory) const
{
//	std::ofstream output(directory + m_path, std::ofstream::binary);
//	std::ostream_iterator<uint8_t> out(output);
//	std::copy(p_impl->data.cbegin(), p_impl->data.cend(), out);
    //m_output->close();
    if(p_impl && p_impl->output) {
        p_impl->output->close();
    }
}

void TSSegment::Remove(std::string directory) const
{
}

std::string TSSegment::Path() const
{
	return m_path;
}

int32_t TSSegment::GetIndex() const
{
	return m_index;
}

void TSSegment::PutFrameImpl(TSPacket frame)
{
	//p_impl->writer.PutBytes(frame.Data().cbegin(), frame.Data().cend());
//    for(auto& byte:frame.Data())
//    {
//        p_impl->data.push_back(byte);
//        //output << byte;
//    }
    if(p_impl && p_impl->output) {
        p_impl->output->write((char*)&frame.Data()[0], frame.Data().size());
        p_impl->dataWritten += frame.Data().size();
    }
}

void TSSegment::CloseImpl()
{
}
