#pragma once
#include "ProgramDescriptor.h"

struct TSProgramDescriptor: public ProgramDescriptor
{
	uint32_t pcrPid;
	uint32_t pid;
};