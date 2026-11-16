#include <assert.h>
#include <stdio.h>
#include <unistd.h>
#include "NetworkPolicy.h"

static int noDelay(int fd) {
    int value = -1;
    socklen_t length = sizeof(value);
    assert(getsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &value, &length) == 0);
    return value;
}

static void testTCP(int domain, int protocol) {
    int fd = socket(domain, SOCK_STREAM, protocol);
    assert(fd >= 0);
    int off = 0;
    assert(setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &off, sizeof(off)) == 0);
    RTConfigureNewSocket(fd, domain, SOCK_STREAM, protocol, false);
    assert(noDelay(fd) == 0);
    errno = EAGAIN;
    RTConfigureNewSocket(fd, domain, SOCK_STREAM, protocol, true);
    assert(errno == EAGAIN);
    assert(noDelay(fd) == 1);
    // The application can override the initial choice without interference.
    assert(setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &off, sizeof(off)) == 0);
    assert(noDelay(fd) == 0);
    close(fd);
}

int main(void) {
    testTCP(AF_INET, 0);
    testTCP(AF_INET6, IPPROTO_TCP);
    int fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    assert(fd >= 0);
    // Rejected classifications must not touch a socket with a measurable option.
    RTConfigureNewSocket(fd, AF_UNIX, SOCK_STREAM, 0, true);
    RTConfigureNewSocket(fd, AF_INET, SOCK_DGRAM, IPPROTO_UDP, true);
    RTConfigureNewSocket(fd, AF_INET, SOCK_STREAM, IPPROTO_UDP, true);
    assert(noDelay(fd) == 0);
    close(fd);
    errno = EBADF;
    RTConfigureNewSocket(-1, AF_INET, SOCK_STREAM, 0, true);
    assert(errno == EBADF);
    puts("PASS: IPv4/IPv6 TCP_NODELAY, disabled and rejected paths, errno, app override");
    return 0;
}
