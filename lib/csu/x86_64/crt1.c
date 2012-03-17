/*-
 * Copyright 1996-1998 John D. Polstra.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef __GNUC__
#error "GCC is needed to compile this file"
#endif

#include <machine/tls.h>
#include <stdlib.h>

#include "libc_private.h"
#include "initfini.c"
#include "crtbrand.c"

typedef void (*fptr)(void);

#ifdef GCRT
extern void _mcleanup(void);
extern void monstartup(void *, void *);
extern int eprol;
extern int etext;
#endif

void _start(char **, void (*)(void));

/* The entry function. */
void
_start(char **ap, void (*cleanup)(void))
{
	int argc;
	char **argv;
	char **env;
	size_t n, array_size;

	argc = *(long *)(void *)ap;
	argv = ap + 1;
	env = ap + 2 + argc;
	environ = env;
	if (argc > 0 && argv[0] != NULL)
		handle_progname(argv[0]);

	/*
	 * Setup the initial TLS space.  The RTLD does not set up our TLS
	 * (it can't, it doesn't know how our errno is declared).  It simply
	 * does all the groundwork required so that we can call
	 * _rtld_allocate_tls().
	 */
	_init_tls();
	_rtld_call_init();

	if (&_DYNAMIC != NULL)
		atexit(cleanup);

#ifdef GCRT
	atexit(_mcleanup);
#endif
	/*
	 * The fini_array needs to be executed in the opposite order of its
	 * definition.  However, atexit works like a LIFO stack, so by
	 * pushing functions in array order, they will be executed in the
	 * reverse order as required.
	 */
	atexit(_fini);
	array_size = __fini_array_end - __fini_array_start;
	for (n = 0; n < array_size; n++)
		atexit(*__fini_array_start [n]);
#ifdef GCRT
	monstartup(&eprol, &etext);
#endif
	if (&_DYNAMIC == NULL) {
		/*
		 * For static executables preinit happens right before init.
		 * Dynamic executable preinit arrays are handled by rtld
		 * before any DSOs are initialized.
		 */
		array_size = __preinit_array_end - __preinit_array_start;
		for (n = 0; n < array_size; n++)
			(*__preinit_array_start [n])(argc, argv, env);
	}
	_init();
	array_size = __init_array_end - __init_array_start;
	for (n = 0; n < array_size; n++)
		(*__init_array_start [n])(argc, argv, env);
	exit(main(argc, argv, env));
}

#ifdef GCRT
__asm__(".text");
__asm__("eprol:");
__asm__(".previous");
#endif
