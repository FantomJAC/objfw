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

#define __NO_EXT_QNX

#include "config.h"

#include <string.h>

#include <errno.h>

#import "OFStreamSocket.h"

#import "OFInitializationFailedException.h"
#import "OFNotConnectedException.h"
#import "OFOutOfRangeException.h"
#import "OFReadFailedException.h"
#import "OFSetOptionFailedException.h"
#import "OFWriteFailedException.h"

#import "socket_helpers.h"

@implementation OFStreamSocket
+ (void)initialize
{
	if (self != [OFStreamSocket class])
		return;

	if (!of_init_sockets())
		@throw [OFInitializationFailedException
		    exceptionWithClass: self];
}

+ (instancetype)socket
{
	return [[[self alloc] init] autorelease];
}

- (bool)lowlevelIsAtEndOfStream
{
	return _atEndOfStream;
}

- (size_t)lowlevelReadIntoBuffer: (void*)buffer
			  length: (size_t)length
{
	ssize_t ret;

	if (_socket == INVALID_SOCKET)
		@throw [OFNotConnectedException exceptionWithSocket: self];

	if (_atEndOfStream) {
		OFReadFailedException *e;

		e = [OFReadFailedException exceptionWithObject: self
					       requestedLength: length];
		e->_errNo = ENOTCONN;
		@throw e;
	}

#ifndef _WIN32
	if ((ret = recv(_socket, buffer, length, 0)) < 0)
		@throw [OFReadFailedException exceptionWithObject: self
						  requestedLength: length];
#else
	if (length > UINT_MAX)
		@throw [OFOutOfRangeException exception];

	if ((ret = recv(_socket, buffer, (unsigned int)length, 0)) < 0)
		@throw [OFReadFailedException exceptionWithObject: self
						  requestedLength: length];
#endif

	if (ret == 0)
		_atEndOfStream = true;

	return ret;
}

- (void)lowlevelWriteBuffer: (const void*)buffer
		     length: (size_t)length
{
	if (_socket == INVALID_SOCKET)
		@throw [OFNotConnectedException exceptionWithSocket: self];

	if (_atEndOfStream) {
		OFWriteFailedException *e;

		e = [OFWriteFailedException exceptionWithObject: self
						requestedLength: length];
		e->_errNo = ENOTCONN;
		@throw e;
	}

#ifndef _WIN32
	if (send(_socket, buffer, length, 0) < length)
		@throw [OFWriteFailedException exceptionWithObject: self
						   requestedLength: length];
#else
	if (length > UINT_MAX)
		@throw [OFOutOfRangeException exception];

	if (send(_socket, buffer, (unsigned int)length, 0) < length)
		@throw [OFWriteFailedException exceptionWithObject: self
						   requestedLength: length];
#endif
}

#ifdef _WIN32
- (void)setBlocking: (bool)enable
{
	u_long v = enable;
	_blocking = enable;

	if (ioctlsocket(_socket, FIONBIO, &v) == SOCKET_ERROR)
		@throw [OFSetOptionFailedException exceptionWithStream: self];
}
#endif

- (int)fileDescriptorForReading
{
#ifndef _WIN32
	return _socket;
#else
	if (_socket > INT_MAX)
		@throw [OFOutOfRangeException exception];

	return (int)_socket;
#endif
}

- (int)fileDescriptorForWriting
{
#ifndef _WIN32
	return _socket;
#else
	if (_socket > INT_MAX)
		@throw [OFOutOfRangeException exception];

	return (int)_socket;
#endif
}

- (void)close
{
	if (_socket == INVALID_SOCKET)
		@throw [OFNotConnectedException exceptionWithSocket: self];

	close(_socket);
	_socket = INVALID_SOCKET;

	_atEndOfStream = false;
}

- (void)dealloc
{
	if (_socket != INVALID_SOCKET)
		[self close];

	[super dealloc];
}
@end
