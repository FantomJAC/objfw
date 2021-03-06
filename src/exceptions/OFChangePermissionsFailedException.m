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

#import "OFChangePermissionsFailedException.h"
#import "OFString.h"

#import "common.h"

@implementation OFChangePermissionsFailedException
+ (instancetype)exceptionWithPath: (OFString*)path
		      permissions: (mode_t)permissions
{
	return [[[self alloc] initWithPath: path
			       permissions: permissions] autorelease];
}

- init
{
	OF_INVALID_INIT_METHOD
}

- initWithPath: (OFString*)path
   permissions: (mode_t)permissions
{
	self = [super init];

	@try {
		_path = [path copy];
		_permissions = permissions;
		_errNo = GET_ERRNO;
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[_path release];

	[super dealloc];
}

- (OFString*)description
{
	return [OFString stringWithFormat:
	    @"Failed to change permissions of item at path %@ to %d! " ERRFMT,
	    _path, _permissions, ERRPARAM];
}

- (OFString*)path
{
	OF_GETTER(_path, true)
}

- (mode_t)permissions
{
	return _permissions;
}

- (int)errNo
{
	return _errNo;
}
@end
