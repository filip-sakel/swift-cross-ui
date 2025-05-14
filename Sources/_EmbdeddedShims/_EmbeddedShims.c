//===--- NumericsShims.c --------------------------------------*- swift -*-===//
//
// This source file is part of the Swift Numerics open source project
//
// Copyright (c) 2019 Apple Inc. and the Swift Numerics project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

// This file exists only to trigger the NumericShims module to build; without
// it swiftpm won't build anything, and then the shims are not available for
// the modules that need them.

// If any shims are added that are not pure header inlines, whatever runtime
// support they require can be added to this file.

#include "_EmbeddedShims.h"

// TimerFDShims.c

// int swift_timerfd_create(void) {
//     // return timerfd_create(CLOCK_MONOTONIC, 0);
//     return 0;
// }

// int swift_timerfd_settime(int fd, int64_t delay_ms) {
//     // struct itimerspec newValue = {0};
//     // newValue.it_value.tv_sec = delay_ms / 1000;
//     // newValue.it_value.tv_nsec = (delay_ms % 1000) * 1000000;
//     // return timerfd_settime(fd, 0, &newValue, NULL);
//     return 0;
// }

// uint64_t swift_timerfd_read(int fd) {
//     // uint64_t expirations = 0;
//     // read(fd, &expirations, sizeof(expirations));
//     // return expirations;
//     return 0;
// }

// // EPOLL

// int swift_epoll_create(void) {
//     // return epoll_create1(0);
//     return 0;
// }

// int swift_epoll_ctl_add(int epoll_fd, int fd, uint32_t events) {
//     // struct epoll_event ev;
//     // ev.events = events;
//     // ev.data.fd = fd;
//     // return epoll_ctl(epoll_fd, EPOLL_CTL_ADD, fd, &ev);
//     return 0;
// }

// int swift_epoll_wait(int epoll_fd, struct epoll_event *events, int max_events, int timeout_ms) {
//     // return epoll_wait(epoll_fd, events, max_events, timeout_ms);
//     return 0;
// }