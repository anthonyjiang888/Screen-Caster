#pragma once
#include <string>
#if defined(_WIN32) || defined(_WIN64)
//#define WIN32_LEAN_AND_MEAN
#define _WINSOCK_DEPRECATED_NO_WARNINGS
#define NOMINMAX
#include <WinSock2.h>
#endif

class NetworkConnection
{
private:
#if defined(_WIN32) || defined(_WIN64)
	SOCKET hSocket;
#else
	int hSocket;
#endif
public:
	NetworkConnection();
	virtual ~NetworkConnection();

	void Connect(std::string address, uint16_t port);
    void Listen(uint16_t port);
	void Close();
	void Send(void* data, size_t bytesCount);
	size_t Receive(void* data, size_t maxBytesCount);
	size_t DataSizeInReceiveBuffer();
};

