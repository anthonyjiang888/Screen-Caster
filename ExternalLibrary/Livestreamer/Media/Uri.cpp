#include "Uri.h"
#include <stdlib.h>


Uri::Uri(std::string uri):
	protocol(""),
	user_info(""),
	host(""),
	port(0),
	path(""),
	query(""),
	fragment("")
{
	Parse(uri);
}


Uri::~Uri()
{
}

std::vector<std::string> Uri::GetSegments()
{
	std::vector<std::string> result;
	if (!host.empty()) result.push_back(host);
	if (!path.empty())
	{
		std::string toBeParsed = path;
		auto delimiterPos = std::string::npos;
		while((delimiterPos = toBeParsed.find_first_of('/'))!=std::string::npos)
		{
			std::string segment = std::string(toBeParsed.cbegin(), toBeParsed.cbegin() + delimiterPos);
			toBeParsed = std::string(toBeParsed.cbegin() + delimiterPos + 1, toBeParsed.cend());
			if (!segment.empty()) result.push_back(segment);
		}
		if (!toBeParsed.empty()) result.push_back(toBeParsed);
	}
	return result;
}

std::string Uri::ToString()
{
	std::string result = protocol;
	if (user_info != "") result += user_info + "@";
	result += host;
	if (port) result += ":" + std::to_string(port);
	result += path;
	result += query;
	result += fragment;
	return result;
}

void Uri::Parse(std::string uri)
{
	std::string toBeParsed = uri;
	auto fragmentPos = toBeParsed.find_last_of('#');
	if (fragmentPos != std::string::npos)
	{
		fragment = std::string(toBeParsed.cbegin() + fragmentPos, toBeParsed.cend());
		toBeParsed = std::string(toBeParsed.cbegin(), toBeParsed.cbegin() + fragmentPos);
	}
	auto queryPos = toBeParsed.find_last_of('?');
	if (queryPos != std::string::npos)
	{
		query = std::string(toBeParsed.cbegin() + queryPos, toBeParsed.cend());
		toBeParsed = std::string(toBeParsed.cbegin(), toBeParsed.cbegin() + queryPos);
	}
	auto protoPos = toBeParsed.find(std::string("://"));
	if (protoPos != std::string::npos)
	{
		protocol = std::string(toBeParsed.cbegin(), toBeParsed.cbegin() + protoPos + 3);
		toBeParsed = std::string(toBeParsed.cbegin() + protoPos + 3, toBeParsed.cend());
	}
	auto userInfoPos = toBeParsed.find_last_of('@');
	if (userInfoPos != std::string::npos)
	{
		user_info = std::string(toBeParsed.cbegin(), toBeParsed.cbegin() + userInfoPos);
		toBeParsed = std::string(toBeParsed.cbegin() + userInfoPos + 1, toBeParsed.cend());
	}
	auto pathPos = toBeParsed.find_first_of('/');
	if (pathPos != std::string::npos)
	{
		path = std::string(toBeParsed.cbegin() + pathPos, toBeParsed.cend());
		toBeParsed = std::string(toBeParsed.cbegin(), toBeParsed.cbegin() + pathPos);
	}
	auto portPos = toBeParsed.find_last_of(':');
	if (portPos != std::string::npos)
	{
		std::string portStr = std::string(toBeParsed.cbegin() + portPos + 1, toBeParsed.cend());
		port = atoi(portStr.c_str());
		toBeParsed = std::string(toBeParsed.cbegin(), toBeParsed.cbegin() + portPos);
	}
	host = toBeParsed;
}
