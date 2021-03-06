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

#import "OFMemoryNotPartOfObjectException.h"
#import "OFString.h"

@implementation OFMemoryNotPartOfObjectException
+ (instancetype)exceptionWithPointer: (void*)pointer
			      object: (id)object
{
	return [[[self alloc] initWithPointer: pointer
				       object: object] autorelease];
}

- init
{
	OF_INVALID_INIT_METHOD
}

- initWithPointer: (void*)pointer
	   object: (id)object
{
	self = [super init];

	_pointer = pointer;
	_object = [object retain];

	return self;
}

- (void)dealloc
{
	[_object release];

	[super dealloc];
}

- (OFString*)description
{
	return [OFString stringWithFormat:
	    @"Memory at %p was not allocated as part of object of type %@, "
	    @"thus the memory allocation was not changed! It is also possible "
	    @"that there was an attempt to free the same memory twice.",
	    _pointer, [_object class]];
}

- (void*)pointer
{
	return _pointer;
}

- (id)object
{
	OF_GETTER(_object, true)
}
@end
