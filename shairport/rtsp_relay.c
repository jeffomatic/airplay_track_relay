#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <netinet/in.h>
#include <sys/socket.h>

#include "rtsp_relay.h"

#ifndef RTSP_RELAY_PORT
#define RTSP_RELAY_PORT 12345
#endif // RTSP_RELAY_PORT

//#define RTSP_RELAY_DEBUG
#ifdef RTSP_RELAY_DEBUG
#define RTSP_RELAY_LOG(...) printf(__VA_ARGS__)
#else
#define RTSP_RELAY_LOG(...)
#endif

static int rtsp_relay_socket = -1;
static struct sockaddr_in rtsp_relay_sockaddr;

void rtsp_relay_init() {
    if ((rtsp_relay_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0) {
        printf("CANNOT CREATE MESSAGE SOCKET");
    } else {
        memset(&rtsp_relay_sockaddr, 0, sizeof(rtsp_relay_sockaddr));
        rtsp_relay_sockaddr.sin_family = AF_INET;
        rtsp_relay_sockaddr.sin_port =  htons((unsigned short)RTSP_RELAY_PORT);
        rtsp_relay_sockaddr.sin_addr.s_addr = INADDR_ANY;
    }
}

void rtsp_relay_message(const rtsp_message* message) {
    RTSP_RELAY_LOG(
        "REQUEST: %s|Headers: %d|Length: %d\n",
        message->method,
        message->nheaders,
        message->contentlength
    );

    for (int i = 0; i < message->nheaders; ++i) {
        RTSP_RELAY_LOG("%s: %s\n", message->name[i], message->value[i]);
    }

    char content[1024 * 10];
    memcpy(content, message->content, message->contentlength);
    content[message->contentlength] = 0;
    for (int i = 0; i < message->contentlength; ++i) {
      if (content[i] == 0) {
        content[i] = '0';
      }
    }

    if (message->contentlength) {
      RTSP_RELAY_LOG("<<CONTENTS\n%s\nCONTENTS>>\n", content);
    }

    RTSP_RELAY_LOG("\n");

    // SEND REQUEST
    if (rtsp_relay_socket >= 0) {
        char buffer[1024 * 20];
        char* buffer_current = buffer;
        memset(buffer, 0, sizeof(buffer));

        // header count
        memcpy(buffer_current, &message->nheaders, sizeof(int));
        buffer_current += sizeof(int);

        // Header names
        for (int i = 0; i < message->nheaders; ++i) {
            int name_length = strlen(message->name[i]);
            int value_length = strlen(message->value[i]);

            // Copy header name length
            memcpy(buffer_current, &name_length, sizeof(name_length));
            buffer_current += sizeof(name_length);

            // Copy header name value
            memcpy(buffer_current, message->name[i], name_length);
            buffer_current += name_length;

            // Copy header value length
            memcpy(buffer_current, &value_length, sizeof(value_length));
            buffer_current += sizeof(value_length);

            // Copy header value string
            memcpy(buffer_current, message->value[i], value_length);
            buffer_current += value_length;
        }

        // Content length
        memcpy(buffer_current, &message->contentlength, sizeof(int));
        buffer_current += sizeof(int);

        // Content
        memcpy(buffer_current, message->content, message->contentlength);
        buffer_current += message->contentlength;

        // Method
        memcpy(buffer_current, &message->method, 16);
        buffer_current += 16;

        RTSP_RELAY_LOG("SENDING MESSAGE: %d bytes\n\n", buffer_current);

        int buffer_size = buffer_current - buffer + 1;
        int sent_bytes = sendto(
            rtsp_relay_socket,
            buffer,
            buffer_size,
            0, // flags
            (struct sockaddr*)&rtsp_relay_sockaddr,
            sizeof(rtsp_relay_sockaddr)
        );

        if (sent_bytes != buffer_size) {
            printf("RTSP relay failed to send packet: return value = %d\n", sent_bytes);
        }
    }
}