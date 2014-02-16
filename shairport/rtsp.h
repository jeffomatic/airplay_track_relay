#ifndef _RTSP_H
#define _RTSP_H

void rtsp_listen_loop(void);
void rtsp_shutdown_stream(void);

typedef struct {
    int nheaders;
    char *name[16];
    char *value[16];

    int contentlength;
    char *content;

    // for requests
    char method[16];

    // for responses
    int respcode;
} rtsp_message;

#endif // _RTSP_H
