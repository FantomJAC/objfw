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

#include <math.h>
#include <errno.h>

#include <assert.h>

#include <sys/types.h>
#include <sys/event.h>
#include <sys/time.h>

#import "OFKernelEventObserver.h"
#import "OFKernelEventObserver+Private.h"
#import "OFKernelEventObserver_kqueue.h"
#import "OFDataArray.h"

#import "OFInitializationFailedException.h"
#import "OFOutOfMemoryException.h"
#import "OFOutOfRangeException.h"

#import "socket_helpers.h"

#define EVENTLIST_SIZE 64

@implementation OFKernelEventObserver_kqueue
- init
{
	self = [super init];

	@try {
		if ((_kernelQueue = kqueue()) == -1)
			@throw [OFInitializationFailedException
			    exceptionWithClass: [self class]];

		_changeList = [[OFDataArray alloc] initWithItemSize:
		    sizeof(struct kevent)];

		[self OF_addFileDescriptorForReading: _cancelFD[0]];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	close(_kernelQueue);
	[_changeList release];

	[super dealloc];
}

- (void)OF_addFileDescriptorForReading: (int)fd
{
	struct kevent event;

	if ([_changeList count] >= INT_MAX)
		@throw [OFOutOfRangeException exception];

	EV_SET(&event, fd, EVFILT_READ, EV_ADD, 0, 0, 0);
	[_changeList addItem: &event];
}

- (void)OF_addFileDescriptorForWriting: (int)fd
{
	struct kevent event;

	if ([_changeList count] >= INT_MAX)
		@throw [OFOutOfRangeException exception];

	EV_SET(&event, fd, EVFILT_WRITE, EV_ADD, 0, 0, 0);
	[_changeList addItem: &event];
}

- (void)OF_removeFileDescriptorForReading: (int)fd
{
	struct kevent event;

	EV_SET(&event, fd, EVFILT_READ, EV_DELETE, 0, 0, 0);
	[_changeList addItem: &event];
}

- (void)OF_removeFileDescriptorForWriting: (int)fd
{
	struct kevent event;

	EV_SET(&event, fd, EVFILT_WRITE, EV_DELETE, 0, 0, 0);
	[_changeList addItem: &event];
}

- (bool)observeForTimeInterval: (of_time_interval_t)timeInterval
{
	void *pool = objc_autoreleasePoolPush();
	struct timespec timeout;
	struct kevent eventList[EVENTLIST_SIZE];
	int i, events, realEvents = 0;

	timeout.tv_sec = (time_t)timeInterval;
	timeout.tv_nsec = lrint((timeInterval - timeout.tv_sec) * 1000000000);

	[self OF_processQueue];

	if ([self OF_processCache]) {
		objc_autoreleasePoolPop(pool);
		return true;
	}

	objc_autoreleasePoolPop(pool);

	events = kevent(_kernelQueue, [_changeList items],
	    (int)[_changeList count], eventList, EVENTLIST_SIZE,
	    (timeInterval == -1 ? NULL : &timeout));

	if (events < 0)
		return false;

	[_changeList removeAllItems];

	if (events == 0)
		return false;

	for (i = 0; i < events; i++) {
		if (eventList[i].ident == _cancelFD[0]) {
			char buffer;

			OF_ENSURE(read(_cancelFD[0], &buffer, 1) > 0);

			continue;
		}

		realEvents++;

		pool = objc_autoreleasePoolPush();

		/*
		 * If a file descriptor has been closed before it is removed
		 * from the kernel event observer, the file descriptor is not
		 * valid anymore and causes EBADF. As closing a file descriptor
		 * automatically removes it from the queue, there is nothing to
		 * do anymore.
		 *
		 * Ideally, a file descriptor should never be closed before it
		 * is removed from the kernel event observer, as in rare cases,
		 * it could result in removing the wrong object from the kernel
		 * event observer, for example if a file descriptor is closed,
		 * a new one created, added to the kernel event observer and
		 * then the old one removed, as the new one could now have the
		 * same file descriptor as the closed one had and thus the new
		 * one is removed.
		 *
		 * For other errors, call the callback like it was successful
		 * so that the read / write will generate an error and throw an
		 * exception.
		 */
		if ((eventList[i].flags & EV_ERROR) &&
		    eventList[i].data == EBADF)
			continue;

		switch (eventList[i].filter) {
		case EVFILT_READ:
			if ([_delegate respondsToSelector:
			    @selector(objectIsReadyForReading:)])
				[_delegate objectIsReadyForReading:
				    _FDToObject[eventList[i].ident]];
			break;
		case EVFILT_WRITE:
			if ([_delegate respondsToSelector:
			    @selector(objectIsReadyForWriting:)])
				[_delegate objectIsReadyForWriting:
				    _FDToObject[eventList[i].ident]];
			break;
		default:
			assert(0);
		}

		objc_autoreleasePoolPop(pool);
	}

	if (realEvents == 0)
		return false;

	return true;
}
@end
