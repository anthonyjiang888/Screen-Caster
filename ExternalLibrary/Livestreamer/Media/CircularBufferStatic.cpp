//
//  CircularBufferStatic.cpp
//  LiveStreamer
//
//  Created by alex on 04/08/2017.
//  Copyright © 2017 alex. All rights reserved.
//

#include "CircularBufferStatic.h"


CircularBufferStatic::CircularBufferStatic(size_t length):
    m_buffer(length),
    m_readingPosition(0),
    m_writingPosition(0)
{
    m_buffer.resize(length);
}

CircularBufferStatic::~CircularBufferStatic()
{

}

void CircularBufferStatic::Clear()
{
    m_readingPosition = 0;
    m_writingPosition = 0;
}

size_t CircularBufferStatic::GetWaterLevel() const
{
    if (m_writingPosition == m_readingPosition) return 0;
    else if (m_writingPosition > m_readingPosition) return m_writingPosition - m_readingPosition;
    else if (m_writingPosition < m_readingPosition) return (m_buffer.size() - m_readingPosition) + m_writingPosition;
    return 0;
}

size_t CircularBufferStatic::GetMaxWriteSize() const
{
    if (m_writingPosition == m_readingPosition) return m_buffer.size() - 1;
    else if (m_writingPosition > m_readingPosition) return (m_buffer.size() - m_writingPosition) + m_readingPosition - 1;
    else if (m_writingPosition < m_readingPosition) return m_readingPosition - m_writingPosition - 1;
    return 0;
}
