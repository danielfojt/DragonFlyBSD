/*
 * Copyright (c) 1982, 1986, 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)file.h	8.3 (Berkeley) 1/9/95
 * $FreeBSD: src/sys/sys/file.h,v 1.22.2.7 2002/11/21 23:39:24 sam Exp $
 * $DragonFly: src/sys/sys/file.h,v 1.3 2003/06/25 03:56:10 dillon Exp $
 */

#ifndef _SYS_FILE_H_
#define	_SYS_FILE_H_

#ifndef _KERNEL
#include <sys/fcntl.h>
#include <sys/unistd.h>
#endif

#ifdef _KERNEL
#include <sys/queue.h>

struct stat;
struct proc;
struct thread;
struct uio;
struct knote;

/*
 * Kernel descriptor table.
 * One entry for each open kernel vnode and socket.
 */
struct file {
	LIST_ENTRY(file) f_list;/* list of active files */
	short	f_FILLER3;	/* (old f_flag) */
#define	DTYPE_VNODE	1	/* file */
#define	DTYPE_SOCKET	2	/* communications endpoint */
#define	DTYPE_PIPE	3	/* pipe */
#define	DTYPE_FIFO	4	/* fifo (named pipe) */
#define	DTYPE_KQUEUE	5	/* event queue */
#define DTYPE_CRYPTO	6	/* crypto */
	short	f_type;		/* descriptor type */
	u_int	f_flag;		/* see fcntl.h */
	struct	ucred *f_cred;	/* credentials associated with descriptor */
	struct	fileops {
		int	(*fo_read)	__P((struct file *fp, struct uio *uio,
					    struct ucred *cred, int flags,
					    struct thread *td));
		int	(*fo_write)	__P((struct file *fp, struct uio *uio,
					    struct ucred *cred, int flags,
					    struct thread *td));
#define	FOF_OFFSET	1
		int	(*fo_ioctl)	__P((struct file *fp, u_long com,
					    caddr_t data, struct thread *td));
		int	(*fo_poll)	__P((struct file *fp, int events,
					    struct ucred *cred, struct thread *td));
		int	(*fo_kqfilter)	__P((struct file *fp,
					    struct knote *kn));
		int	(*fo_stat)	__P((struct file *fp, struct stat *sb,
					    struct thread *td));
		int	(*fo_close)	__P((struct file *fp, struct thread *td));
	} *f_ops;
	int	f_seqcount;	/*
				 * count of sequential accesses -- cleared
				 * by most seek operations.
				 */
	off_t	f_nextoff;	/*
				 * offset of next expected read or write
				 */
	off_t	f_offset;
	caddr_t	f_data;		/* vnode or socket */
	int	f_count;	/* reference count */
	int	f_msgcount;	/* reference count from message queue */
};

#ifdef MALLOC_DECLARE
MALLOC_DECLARE(M_FILE);
#endif

extern int fdrop __P((struct file *fp, struct thread *td));

LIST_HEAD(filelist, file);
extern struct filelist filehead; /* head of list of open files */
extern struct fileops vnops;
extern struct fileops badfileops;
extern int maxfiles;		/* kernel limit on number of open files */
extern int maxfilesperproc;	/* per process limit on number of open files */
extern int nfiles;		/* actual number of open files */

#endif /* _KERNEL */

#endif /* !SYS_FILE_H */
