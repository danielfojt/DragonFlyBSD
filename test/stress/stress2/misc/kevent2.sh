#!/bin/sh

#
# Copyright (c) 2008 Peter Holm <pho@FreeBSD.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $FreeBSD$
#

. ../default.cfg

odir=`pwd`

cd /tmp
sed '1,/^EOF/d' < $odir/$0 > kevent.c
cc -o kevent -Wall kevent.c -pthread
rm -f kevent.c
cd $RUNDIR

for i in `jot 10`; do
	for j in `jot 12`; do
		/tmp/kevent > /dev/null 2>&1 &
	done
	for j in `jot 12`; do
		wait
	done
done
exit
EOF
#include <pthread.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/event.h>
#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t  cond  = PTHREAD_COND_INITIALIZER;
static int waiting;

static int fd1[2];
static int fd2[2];
static int fd3[2];

void *
thr1(void *arg)
{
	int n;
	int kq = -1;
	struct kevent ev[3];
	struct timespec ts;

	if ((kq = kqueue()) < 0)
		err(1, "kqueue(). %s:%d", __FILE__, __LINE__);

	n = 0;
	EV_SET(&ev[n], fd1[1], EVFILT_WRITE,
		    EV_ADD | EV_ENABLE | EV_CLEAR, 0, 0, 0);
	n++;
	EV_SET(&ev[n], fd2[1], EVFILT_WRITE,
		    EV_ADD | EV_ENABLE | EV_CLEAR, 0, 0, 0);
	n++;
	EV_SET(&ev[n], fd3[1], EVFILT_WRITE,
		    EV_ADD | EV_ENABLE | EV_CLEAR, 0, 0, 0);
	n++;

	if (kevent(kq, ev, n, NULL, 0, NULL) < 0)
		err(1, "kevent(). %s:%d", __FILE__, __LINE__);

	if (pthread_mutex_lock(&mutex) == -1)
		err(1, "pthread_mutex_lock");
	waiting = 0;
	if (pthread_cond_signal(&cond) == -1)
		err(1, "pthread_cond_signal");
	if (pthread_mutex_unlock(&mutex) == -1)
		err(1, "pthread_mutex_unlock");

	n = 0;
	EV_SET(&ev[n], fd1[1], EVFILT_WRITE,
		    EV_DELETE, 0, 0, 0);
	n++;
	ts.tv_sec = 0;
	ts.tv_nsec = 0;
	if (kevent(kq, ev, n, NULL, 0, &ts) < 0)
		err(1, "kevent(). %s:%d", __FILE__, __LINE__);
	close(kq);

//	printf("%s:%d\n", __FILE__, __LINE__); fflush(stdout);
	close(fd1[1]);
	close(fd2[1]);
	close(fd3[1]);
	return (0);
}

void *
thr2(void *arg)
{
	if (pthread_mutex_lock(&mutex) == -1)
		err(1, "pthread_mutex_lock");
	while (waiting == 1) {
		if (pthread_cond_wait(&cond, &mutex) == -1)
			err(1, "pthread_cond_wait");
	}
	if (pthread_mutex_unlock(&mutex) == -1)
		err(1, "pthread_mutex_unlock");
//	printf("%s:%d\n", __FILE__, __LINE__); fflush(stdout);
	close(fd1[0]);
	close(fd2[0]);
	close(fd3[0]);
	return (0);
}

int
main(int argc, char **argv)
{
	pthread_t threads[2];
	int r;
	int i;

	for (i = 0; i < 1000; i++) {
		waiting = 1;
//		printf("%s:%d\n", __FILE__, __LINE__); fflush(stdout);
		if (pipe(fd1) == -1)
			err(1, "pipe()");
		if (pipe(fd2) == -1)
			err(1, "pipe()");
		if (pipe(fd3) == -1)
			err(1, "pipe()");

		if (pthread_mutex_init(&mutex, 0) == -1)
			err(1, "pthread_mutex_init");
		if (pthread_cond_init(&cond, NULL) == -1)
			err(1, "pthread_cond_init");

		if ((r = pthread_create(&threads[0], NULL, thr1, 0)) != 0)
			err(1, "pthread_create(): %s\n", strerror(r));
		if ((r = pthread_create(&threads[1], NULL, thr2, 0)) != 0)
			err(1, "pthread_create(): %s\n", strerror(r));

		if (pthread_join(threads[0], NULL) != 0)
			err(1, "pthread_join(%d)", 0);
		if (pthread_join(threads[1], NULL) != 0)
			err(1, "pthread_join(%d)", 1);
		if (pthread_mutex_destroy(&mutex) == -1)
			err(1, "pthread_mutex_destroy");
		if (pthread_cond_destroy(&cond) == -1)
			err(1, "pthread_condattr_destroy");
	}

	return (0);
}
