/*	$NetBSD: search.h,v 1.12 1999/02/22 10:34:28 christos Exp $	*/
/* $FreeBSD: src/include/search.h,v 1.3.2.1 2000/08/17 07:38:34 jhb Exp $ */
/* $DragonFly: src/include/search.h,v 1.4 2003/11/14 01:01:43 dillon Exp $ */

/*
 * Written by J.T. Conklin <jtc@netbsd.org>
 * Public domain.
 */

#ifndef _SEARCH_H_
#define _SEARCH_H_

#include <sys/cdefs.h>
#include <machine/stdint.h>

#ifndef _SIZE_T_DECLARED_
#define _SIZE_T_DECLARED_
typedef __size_t        size_t;
#endif

typedef struct entry {
	char *key;
	void *data;
} ENTRY;

typedef enum {
	FIND, ENTER
} ACTION;

typedef enum {
	preorder,
	postorder,
	endorder,
	leaf
} VISIT;

#ifdef _SEARCH_PRIVATE
typedef struct node {
	char         *key;
	struct node  *llink, *rlink;
} node_t;
#endif

__BEGIN_DECLS
int	 hcreate (size_t);
void	 hdestroy (void);
ENTRY	*hsearch (ENTRY, ACTION);
void	*tdelete (const void *, void **,
		      int (*)(const void *, const void *));
void	*tfind (const void *, void **,
		      int (*)(const void *, const void *));
void	*tsearch (const void *, void **, 
		      int (*)(const void *, const void *));
void      twalk (const void *, void (*)(const void *, VISIT, int));
__END_DECLS

#endif /* !_SEARCH_H_ */
