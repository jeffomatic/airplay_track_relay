#ifndef _RTSP_RELAY_H
#define _RTSP_RELAY_H

#include "rtsp.h"

void rtsp_relay_init();
void rtsp_relay_message(const rtsp_message* message);

#endif // _RTSP_RELAY_H