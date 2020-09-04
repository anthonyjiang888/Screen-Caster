//
//  CircularBufferStatic.hpp
//  LiveStreamer
//
//  Created by alex on 04/08/2017.
//  Copyright © 2017 alex. All rights reserved.
//

#ifndef CircularBufferStatic_hpp
#define CircularBufferStatic_hpp

#include <stdio.h>
#include <vector>
#include <algorithm>

class CircularBufferStatic
{
public:
    CircularBufferStatic(size_t length);
    virtual ~CircularBufferStatic();
    void Clear();
    size_t GetWaterLevel() const;
    size_t GetMaxWriteSize() const;
    
    template<class T>
    size_t Peek(T it, size_t count) const
    {
        if (count > GetWaterLevel()) count = GetWaterLevel();
        if (count == 0) return 0;
        // easy case, no wrapping
        if (m_readingPosition + count <= m_buffer.size())
        {
            //Array.Copy(m_buffer, m_readingPosition, buffer, offset, count);
            std::copy(m_buffer.cbegin() + m_readingPosition, m_buffer.cbegin() + m_readingPosition + count, it);
        }
        else // harder case, buffer wraps
        {
            size_t firstChunkSize = m_buffer.size() - m_readingPosition;
            size_t secondChunkSize = count - firstChunkSize;
            
            //Array.Copy(m_buffer, m_readingPosition, buffer, offset, firstChunkSize);
            //Array.Copy(m_buffer, 0, buffer, offset + firstChunkSize, secondChunkSize);
            std::copy(m_buffer.cbegin() + m_readingPosition, m_buffer.cbegin() + m_readingPosition + firstChunkSize, it);
            std::copy(m_buffer.cbegin(), m_buffer.cbegin() + secondChunkSize, it + firstChunkSize);
        }
        return count;
    }
    
    template<class T>
    size_t Read(T it, size_t count)
    {
        if (count > GetWaterLevel()) count = GetWaterLevel();
        if (count == 0) return 0;
        // easy case, no wrapping
        if (m_readingPosition + count <= m_buffer.size())
        {
            //Array.Copy(m_buffer, m_readingPosition, buffer, offset, count);
            std::copy(m_buffer.cbegin() + m_readingPosition, m_buffer.cbegin() + m_readingPosition + count, it);
            m_readingPosition += count;
        }
        else // harder case, buffer wraps
        {
            size_t firstChunkSize = m_buffer.size() - m_readingPosition;
            size_t secondChunkSize = count - firstChunkSize;
            
            //Array.Copy(m_buffer, m_readingPosition, buffer, offset, firstChunkSize);
            //Array.Copy(m_buffer, 0, buffer, offset + firstChunkSize, secondChunkSize);
            std::copy(m_buffer.cbegin() + m_readingPosition, m_buffer.cbegin() + m_readingPosition + firstChunkSize, it);
            std::copy(m_buffer.cbegin(), m_buffer.cbegin() + secondChunkSize, it + firstChunkSize);
            
            m_readingPosition = secondChunkSize;
        }
        return count;
    }
    
    template<class T>
    bool Write(T it, size_t count)
    {
        if (GetMaxWriteSize() < count) return false;
        // easy case
        if (m_writingPosition + count < m_buffer.size())
        {
            //Array.Copy(buffer, offset, m_buffer, m_writingPosition, count);
            std::copy(it, it + count, m_buffer.begin() + m_writingPosition);
            m_writingPosition += count;
        }
        else // harder case we need to wrap
        {
            size_t firstChunkSize = m_buffer.size() - m_writingPosition;
            size_t secondChunkSize = count - firstChunkSize;
            
            //Array.Copy(buffer, offset, m_buffer, m_writingPosition, firstChunkSize);
            //Array.Copy(buffer, offset + firstChunkSize, m_buffer, 0, secondChunkSize);
            std::copy(it, it + firstChunkSize, m_buffer.begin() + m_writingPosition);
            std::copy(it + firstChunkSize, it + firstChunkSize + secondChunkSize, m_buffer.begin());
            
            m_writingPosition = secondChunkSize;
        }
        return true;
    }

private:
    std::vector<uint8_t> m_buffer;
    size_t m_readingPosition;
    size_t m_writingPosition;
};

#endif /* CircularBufferStatic_hpp */
