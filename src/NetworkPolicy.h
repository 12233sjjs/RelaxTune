#ifndef RT_NETWORK_POLICY_H
#define RT_NETWORK_POLICY_H
#include <stdbool.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>

// Apply once at creation; later application socket options remain authoritative.
static inline void RTConfigureNewSocket(int fd, int domain, int type, int protocol,
                                         bool enabled) {
    int savedError = errno;
#ifdef SOCK_NONBLOCK
    type &= ~SOCK_NONBLOCK;
#endif
#ifdef SOCK_CLOEXEC
    type &= ~SOCK_CLOEXEC;
#endif
    if (enabled && fd >= 0 && (domain == AF_INET || domain == AF_INET6) &&
        type == SOCK_STREAM && (protocol == 0 || protocol == IPPROTO_TCP)) {
        int value = 1;
        (void)setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &value, sizeof(value));
    }
    errno = savedError;
}
#endif
