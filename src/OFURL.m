/*
 * Copyright (c) 2008, 2009, 2010, 2011
 *   Jonathan Schleifer <js@webkeks.org>
 *
 * All rights reserved.
 *
 * This file is part of ObjFW. It may be distributed under the terms of the
 * Q Public License 1.0, which can be found in the file LICENSE.QPL included in
 * the packaging of this file.
 *
 * Alternatively, it may be distributed under the terms of the GNU General
 * Public License, either version 2 or 3, which can be found in the file
 * LICENSE.GPLv2 or LICENSE.GPLv3 respectively included in the packaging of this
 * file.
 */

#include "config.h"

#include <stdlib.h>
#include <string.h>
#include <assert.h>

#import "OFURL.h"
#import "OFString.h"
#import "OFAutoreleasePool.h"
#import "OFExceptions.h"
#import "macros.h"

#define ADD_STR_HASH(str)			\
	h = [str hash];				\
	OF_HASH_ADD(hash, h >> 24);		\
	OF_HASH_ADD(hash, (h >> 16) & 0xFF);	\
	OF_HASH_ADD(hash, (h >> 8) & 0xFF);	\
	OF_HASH_ADD(hash, h & 0xFF);

@implementation OFURL
+ URLWithString: (OFString*)str
{
	return [[[self alloc] initWithString: str] autorelease];
}

- initWithString: (OFString*)str
{
	char *str_c, *str_c2 = NULL;

	self = [super init];

	@try {
		char *tmp, *tmp2;

		if ((str_c2 = strdup([str cString])) == NULL)
			@throw [OFOutOfMemoryException
			     newWithClass: isa
			    requestedSize: [str cStringLength]];

		str_c = str_c2;

		if (!strncmp(str_c, "http://", 7)) {
			scheme = @"http";
			str_c += 7;
		} else if (!strncmp(str_c, "https://", 8)) {
			scheme = @"https";
			str_c += 8;
		} else
			@throw [OFInvalidFormatException newWithClass: isa];

		if ((tmp = strchr(str_c, '/')) != NULL) {
			*tmp = '\0';
			tmp++;
		}

		if ((tmp2 = strchr(str_c, '@')) != NULL) {
			char *tmp3;

			*tmp2 = '\0';
			tmp2++;

			if ((tmp3 = strchr(str_c, ':')) != NULL) {
				*tmp3 = '\0';
				tmp3++;

				user = [[OFString alloc]
				    initWithCString: str_c];
				password = [[OFString alloc]
				    initWithCString: tmp3];
			} else
				user = [[OFString alloc]
				    initWithCString: str_c];

			str_c = tmp2;
		}

		if ((tmp2 = strchr(str_c, ':')) != NULL) {
			OFAutoreleasePool *pool;
			OFString *port_str;

			*tmp2 = '\0';
			tmp2++;

			host = [[OFString alloc] initWithCString: str_c];

			pool = [[OFAutoreleasePool alloc] init];
			port_str = [[OFString alloc] initWithCString: tmp2];

			if ([port_str decimalValue] > 65535)
				@throw [OFInvalidFormatException
				    newWithClass: isa];

			port = [port_str decimalValue];

			[pool release];
		} else {
			host = [[OFString alloc] initWithCString: str_c];

			if ([scheme isEqual: @"http"])
				port = 80;
			else if ([scheme isEqual: @"https"])
				port = 443;
			else
				assert(0);
		}

		if ((str_c = tmp) != NULL) {
			if ((tmp = strchr(str_c, '#')) != NULL) {
				*tmp = '\0';

				fragment = [[OFString alloc]
				    initWithCString: tmp + 1];
			}

			if ((tmp = strchr(str_c, '?')) != NULL) {
				*tmp = '\0';

				query = [[OFString alloc]
				    initWithCString: tmp + 1];
			}

			if ((tmp = strchr(str_c, ';')) != NULL) {
				*tmp = '\0';

				parameters = [[OFString alloc]
				    initWithCString: tmp + 1];
			}

			path = [[OFString alloc] initWithCString: str_c];
		}
	} @catch (id e) {
		[self release];
		@throw e;
	} @finally {
		if (str_c2 != NULL)
			free(str_c2);
	}

	return self;
}

- (void)dealloc
{
	[scheme release];
	[host release];
	[user release];
	[password release];
	[path release];
	[parameters release];
	[query release];
	[fragment release];

	[super dealloc];
}

- (BOOL)isEqual: (id)obj
{
	OFURL *url;

	if (![obj isKindOfClass: [OFURL class]])
		return NO;

	url = obj;

	if (![url->scheme isEqual: scheme])
		return NO;
	if (![url->host isEqual: host])
		return NO;
	if (url->port != port)
		return NO;
	if (![url->user isEqual: user])
		return NO;
	if (![url->password isEqual: password])
		return NO;
	if (![url->path isEqual: path])
		return NO;
	if (![url->parameters isEqual: parameters])
		return NO;
	if (![url->query isEqual: query])
		return NO;
	if (![url->fragment isEqual: fragment])
		return NO;

	return YES;
}

- (uint32_t)hash
{
	uint32_t hash, h;

	OF_HASH_INIT(hash);

	ADD_STR_HASH(scheme);
	ADD_STR_HASH(host);

	OF_HASH_ADD(hash, (port >> 8) & 0xFF);
	OF_HASH_ADD(hash, port & 0xFF);

	ADD_STR_HASH(user);
	ADD_STR_HASH(password);
	ADD_STR_HASH(path);
	ADD_STR_HASH(parameters);
	ADD_STR_HASH(query);
	ADD_STR_HASH(fragment);

	OF_HASH_FINALIZE(hash);

	return hash;
}

- copy
{
	OFURL *new = [[OFURL alloc] init];

	new->scheme = [scheme copy];
	new->host = [host copy];
	new->port = port;
	new->user = [user copy];
	new->password = [password copy];
	new->path = [path copy];
	new->parameters = [parameters copy];
	new->query = [query copy];
	new->fragment = [fragment copy];

	return new;
}

- (OFString*)scheme
{
	return [[scheme copy] autorelease];
}

- (void)setScheme: (OFString*)scheme_
{
	if (![scheme_ isEqual: @"http"] && ![scheme_ isEqual: @"https"])
		@throw [OFInvalidArgumentException newWithClass: isa
						       selector: _cmd];

	OFString *old = scheme;
	scheme = [scheme_ copy];
	[old release];
}

- (OFString*)host
{
	return [[host copy] autorelease];
}

- (void)setHost: (OFString*)host_
{
	OFString *old = host;
	host = [host_ copy];
	[old release];
}

- (uint16_t)port
{
	return port;
}

- (void)setPort: (uint16_t)port_
{
	port = port_;
}

- (OFString*)user
{
	return [[user copy] autorelease];
}

- (void)setUser: (OFString*)user_
{
	OFString *old = user;
	user = [user_ copy];
	[old release];
}

- (OFString*)password
{
	return [[password copy] autorelease];
}

- (void)setPassword: (OFString*)password_
{
	OFString *old = password;
	password = [password_ copy];
	[old release];
}

- (OFString*)path
{
	return [[path copy] autorelease];
}

- (void)setPath: (OFString*)path_
{
	OFString *old = path;
	path = [path_ copy];
	[old release];
}

- (OFString*)parameters
{
	return [[parameters copy] autorelease];
}

- (void)setParameters: (OFString*)parameters_
{
	OFString *old = parameters;
	parameters = [parameters_ copy];
	[old release];
}

- (OFString*)query
{
	return [[query copy] autorelease];
}

- (void)setQuery: (OFString*)query_
{
	OFString *old = query;
	query = [query_ copy];
	[old release];
}

- (OFString*)fragment
{
	return [[fragment copy] autorelease];
}

- (void)setFragment: (OFString*)fragment_
{
	OFString *old = fragment;
	fragment = [fragment_ copy];
	[old release];
}

- (OFString*)description
{
	OFMutableString *desc = [OFMutableString stringWithFormat: @"%@://",
								   scheme];
	BOOL needPort = YES;

	if (user != nil && password != nil)
		[desc appendFormat: @"%@:%@@", user, password];
	else if (user != nil)
		[desc appendFormat: @"%@@", user];

	[desc appendString: host];

	if (([scheme isEqual: @"http"] && port == 80) ||
	    ([scheme isEqual: @"https"] && port == 443))
		needPort = NO;

	if (needPort)
		[desc appendFormat: @":%d", port];

	if (path != nil)
		[desc appendFormat: @"/%@", path];

	if (parameters != nil)
		[desc appendFormat: @";%@", parameters];

	if (query != nil)
		[desc appendFormat: @"?%@", query];

	if (fragment != nil)
		[desc appendFormat: @"#%@", fragment];

	return desc;
}
@end