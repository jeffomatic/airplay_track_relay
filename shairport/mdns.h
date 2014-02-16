#ifndef _MDNS_H
#define _MDNS_H

extern int mdns_pid;

void mdns_unregister(void);
void mdns_register(void);
void mdns_ls_backends(void);

typedef struct {
    char *name;
    int (*mdns_register)(char *apname, int port);
    void (*mdns_unregister)(void);
} mdns_backend;

#ifdef ENABLE_RTSP_RELAY
// Request additional metadata
#define MDNS_RECORD  "tp=UDP", "sm=false", "ek=1", "et=0,1", "cn=0,1", "ch=2", "md=0", \
                "ss=16", "sr=44100", "vn=3", "txtvers=1", \
                config.password ? "pw=true" : "pw=false"
#else
#define MDNS_RECORD  "tp=UDP", "sm=false", "ek=1", "et=0,1", "cn=0,1", "ch=2", \
                "ss=16", "sr=44100", "vn=3", "txtvers=1", \
                config.password ? "pw=true" : "pw=false"
#endif // ENABLE_RTSP_RELAY

#endif // _MDNS_H
