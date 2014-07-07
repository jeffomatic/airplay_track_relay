#define METADATA_RELAY_DEBUG
#ifdef METADATA_RELAY_DEBUG
#define METADATA_RELAY_LOG(...) printf(__VA_ARGS__)
#define METADATA_RELAY_LOG_BYTES(_buffer_, _length_) \
  for (int metadata_byte_counter = 0; metadata_byte_counter < _length_; ++metadata_byte_counter) { \
    printf("%c", *(char*)(_buffer_ + metadata_byte_counter)); \
  }
#else
#define METADATA_RELAY_LOG(...)
#define METADATA_RELAY_LOG_BYTES(...)
#endif

#define METADATA_RELAY_PORT 12345

#include <stdio.h>
#include <string.h>
#include <netinet/in.h>
#include <sys/socket.h>

static int rtsp_relay_socket = -1;
static struct sockaddr_in rtsp_relay_sockaddr;

void metadata_relay_init()
{
  METADATA_RELAY_LOG("Initializing metadata relay on port %d\n", METADATA_RELAY_PORT);

  if ((rtsp_relay_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0) {
    printf("CANNOT CREATE METADATA RELAY SOCKET");
  } else {
    memset(&rtsp_relay_sockaddr, 0, sizeof(rtsp_relay_sockaddr));
    rtsp_relay_sockaddr.sin_family = AF_INET;
    rtsp_relay_sockaddr.sin_port =  htons((unsigned short)METADATA_RELAY_PORT);
    rtsp_relay_sockaddr.sin_addr.s_addr = INADDR_ANY;
  }
}

void metadata_relay_send(void* buffer, int length)
{
  METADATA_RELAY_LOG("\n<metadata>\n");
  METADATA_RELAY_LOG_BYTES(buffer, length);
  METADATA_RELAY_LOG("\n</metadata>\n");

  int sent_bytes = sendto(
    rtsp_relay_socket,
    buffer,
    length,
    0, // flags
    (struct sockaddr*)&rtsp_relay_sockaddr,
    sizeof(rtsp_relay_sockaddr)
  );

  if (sent_bytes != length) {
      printf("Metadata relay failed to send packet: return value = %d\n", sent_bytes);
  }
}