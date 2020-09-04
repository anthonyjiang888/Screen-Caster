#pragma once
#include "MediaDescriptor.h"
#include "MediaBuffer.h"
#include "Enums.h"
#include "BitstreamReader.h"
#include "BitstreamWriter.h"
#include <memory>


namespace std
{
#if !defined(_WIN32) && !defined(_WIN64)
//    template<typename T, typename ...Args>
//    unique_ptr<T> make_unique( Args&& ...args )
//    {
//        return unique_ptr<T>( new T( forward<Args>(args)... ) );
//    };
#endif
}


class MediaFrame
{
private:
	struct MediaFrameImplementation
	{
		MediaBuffer data;
		MediaDescriptor descriptor;
		MediaFrameImplementation(MediaType type, MediaCodec codec):
			descriptor(type, codec),
			m_pts(0),
			m_keyFrame(false)
		{
		}
		double m_pts;
        double m_dts;
		bool m_keyFrame;
	};
	std::shared_ptr<MediaFrameImplementation> p_impl;


public:
	MediaFrame(MediaType type = MediaType::Unknown, MediaCodec codec = MediaCodec::Unknown);
	virtual ~MediaFrame();

	MediaBuffer& Data();
	MediaDescriptor& Descriptor();
	double PTS();
	void SetPTS(double pts);
    double DTS();
    void SetDTS(double pts);
	bool KeyFrame();
	void SetKeyFrame(bool keyFrame);

	BitstreamReader GetDataReader();
	BitstreamWriter GetDataWriter();
};

