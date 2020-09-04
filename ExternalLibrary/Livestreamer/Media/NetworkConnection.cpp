#include "NetworkConnection.h"
#if defined(_WIN32) || defined(_WIN64)
#include <Windows.h>
#pragma comment(lib,"WS2_32")
#else
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdlib.h>
#include <errno.h>
#include <netdb.h>
#endif


NetworkConnection::NetworkConnection()
{
}


NetworkConnection::~NetworkConnection()
{
	Close();
}

void NetworkConnection::Connect(std::string address, uint16_t port)
{
	Close();
#if defined(_WIN32) || defined(_WIN64)
	WSADATA ws;
	if (FAILED(WSAStartup(MAKEWORD(1, 1), &ws))) throw std::runtime_error("WSAStartup error");
	SOCKADDR_IN addr; //Socket address information
#else
	sockaddr_in addr;
#endif


	addr.sin_family = AF_INET; // address family Internet
	addr.sin_port = htons((u_short)port); //Port to connect on
	addr.sin_addr.s_addr = inet_addr(address.c_str()); //Target IP
	if (addr.sin_addr.s_addr == -1) {
		errno = 0;
		hostent* hostEntry;
		if ((hostEntry = gethostbyname(address.c_str())))
			memcpy((char *)&addr.sin_addr.s_addr, hostEntry->h_addr, hostEntry->h_length);
		else {
			throw std::runtime_error("unknown host: " + address);
		}
	}

#if defined(_WIN32) || defined(_WIN64)
	hSocket = WSASocket(AF_INET, SOCK_STREAM, IPPROTO_TCP, NULL, NULL, 0);
	if (hSocket == INVALID_SOCKET)
	{
#else
	hSocket = socket(AF_INET, SOCK_STREAM, 0);
	if (hSocket < 0)
	{
#endif
		throw std::runtime_error("can't open socket");
	}
#if !defined(_WIN32) && !defined(_WIN64)
	int set = 1;
    setsockopt(hSocket, SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(int));
#endif
#if defined(_WIN32) || defined(_WIN64)
	if (connect(hSocket, (SOCKADDR *)&addr, sizeof(addr)) == SOCKET_ERROR)
#else
	if (connect(hSocket, (struct sockaddr *)&addr, sizeof(addr)) < 0)
#endif	
	{
		throw std::runtime_error("can't connect socket");
	}
}

struct sockaddr_in getipa(const char* hostname, int port){
    struct sockaddr_in ipa;
    ipa.sin_family = AF_INET;
    ipa.sin_port = htons(port);
    
    struct hostent* localhost = gethostbyname(hostname);
    if(!localhost){
       
        return ipa;
    }
    
    char* addr = localhost->h_addr_list[0];
    memcpy(&ipa.sin_addr.s_addr, addr, sizeof addr);
    
    return ipa;
}
    
void NetworkConnection::Listen(uint16_t port)
{
    Close();
#if defined(_WIN32) || defined(_WIN64)
    WSADATA ws;
    if (FAILED(WSAStartup(MAKEWORD(1, 1), &ws))) throw std::runtime_error("WSAStartup error");
    SOCKADDR_IN addr; //Socket address information
#else
    sockaddr_in addr;
#endif
    
    
    addr = getipa("localhost", 8080);
    
#if defined(_WIN32) || defined(_WIN64)
    hSocket = WSASocket(AF_INET, SOCK_STREAM, IPPROTO_TCP, NULL, NULL, 0);
    if (hSocket == INVALID_SOCKET)
    {
#else
    hSocket = socket(AF_INET, SOCK_STREAM, 0);
    if (hSocket < 0)
    {
#endif
        throw std::runtime_error("can't open socket");
    }
#if !defined(_WIN32) && !defined(_WIN64)
    int set = 1;
    setsockopt(hSocket, SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(int));
#endif
#if defined(_WIN32) || defined(_WIN64)
    if (connect(hSocket, (SOCKADDR *)&addr, sizeof(addr)) == SOCKET_ERROR)
#else
    if (connect(hSocket, (struct sockaddr *)&addr, sizeof(addr)) < 0)
#endif
    {
        throw std::runtime_error("can't connect socket");
    }
}

void NetworkConnection::Close()
{
	if (hSocket)
	{
#if defined(_WIN32) || defined(_WIN64)
		closesocket(hSocket);
#else
		close(hSocket);
#endif
		hSocket = 0;
	}
}

void NetworkConnection::Send(void * data, size_t bytesCount)
{
	size_t total = 0;
	do
	{
		size_t cb = (uint32_t)send(hSocket, (char*)data + total,	bytesCount - total,	0);
		if (cb == -1 || cb == 0) throw std::runtime_error("network send data failed");
		total += cb;
	} while (total < bytesCount);
}

size_t NetworkConnection::Receive(void * data, size_t maxBytesCount)
{
	size_t total = 0;
    int attempt = 0;
	do
	{
		size_t cb = recv(hSocket, (char*)data + total, maxBytesCount - total, 0);
        if (cb == -1 || cb == 0)
        {
            if(attempt > 10) throw std::runtime_error("netowrk recv data failed");
            sleep(100);
            attempt++;
            continue;
        }
		total += cb;
	} while (total < maxBytesCount);
	return total;
}
    
    

size_t NetworkConnection::DataSizeInReceiveBuffer()
{
	u_long count;
#if defined(_WIN32) || defined(_WIN64)
	ioctlsocket(hSocket, FIONREAD, &count);
#else
	ioctl(hSocket, FIONREAD, &count);
#endif
	return size_t(count);
}
