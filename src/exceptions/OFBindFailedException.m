/*
 * Copyright (c) 2008, 2009, 2010, 2011, 2012, 2013, 2014
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

#import "OFBindFailedException.h"
#import "OFString.h"

#import "common.h"

@implementation OFBindFailedException
+ (instancetype)exceptionWithHost: (OFString*)host
			     port: (uint16_t)port
			   socket: (id)socket
{
	return [[[self alloc] initWithHost: host
				      port: port
				    socket: socket] autorelease];
}

- init
{
	OF_INVALID_INIT_METHOD
}

- initWithHost: (OFString*)host
	  port: (uint16_t)port
	socket: (id)socket
{
	self = [super init];

	@try {
		_host   = [host copy];
		_port   = port;
		_socket = [socket retain];
		_errNo  = GET_SOCK_ERRNO;
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[_host release];
	[_socket release];

	[super dealloc];
}

- (OFString*)description
{
	return [OFString stringWithFormat:
	    @"Binding to port %" @PRIu16 @" on host %@ failed in socket of "
	    @"type %@! " ERRFMT, _port, _host, [_socket class], ERRPARAM];
}

- (OFString*)host
{
	OF_GETTER(_host, true)
}

- (uint16_t)port
{
	return _port;
}

- (id)socket
{
	OF_GETTER(_socket, true)
}

- (int)errNo
{
#ifdef _WIN32
	return of_wsaerr_to_errno(_errNo);
#else
	return _errNo;
#endif
}
@end
