#pragma once
#include <string>
#include <vector>

class Uri
{
private:
	void Parse(std::string uri);

public:
	Uri(std::string uri = "");
	virtual ~Uri();

	std::string protocol;
	std::string user_info;
	std::string host;
	uint16_t port;
	std::string path;
	std::string query;
	std::string fragment;
	
	std::vector<std::string> GetSegments();
	std::string ToString();
};

