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

#import "OFSet.h"
#import "OFAutoreleasePool.h"
#import "OFArray.h"

#import "TestsAppDelegate.h"

static OFString *module = @"OFSet";

@implementation TestsAppDelegate (OFSetTests)
- (void)setTests
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];
	OFSet *set1, *set2;
	OFMutableSet *mutableSet;
#ifdef OF_HAVE_FAST_ENUMERATION
	BOOL ok;
	size_t i;
#endif

	TEST(@"+[setWithArray:]",
	    (set1 = [OFSet setWithArray: [OFArray arrayWithObjects: @"foo",
	    @"bar", @"baz", @"foo", @"x", nil]]))

	TEST(@"+[setWithObjects:]",
	    (set2 = [OFSet setWithObjects: @"foo", @"bar", @"baz", @"bar", @"x",
	    nil]))

	TEST(@"-[isEqual:]", [set1 isEqual: set2])

	TEST(@"-[hash]", [set1 hash] == [set2 hash])

	TEST(@"-[description]",
	    [[set1 description]
	    isEqual: @"{(\n\tbar,\n\tbaz,\n\tfoo,\n\tx\n)}"] &&
	    [[set1 description] isEqual: [set2 description]])

	TEST(@"-[copy]", [set1 isEqual: [[set1 copy] autorelease]])

	TEST(@"-[mutableCopy]",
	    (mutableSet = [[set1 mutableCopy] autorelease]));

	TEST(@"-[addObject:]",
	    R([mutableSet addObject: @"baz"]) && [mutableSet isEqual: set2] &&
	    R([mutableSet addObject: @"y"]) && [mutableSet isEqual:
	    ([OFSet setWithObjects: @"foo", @"bar", @"baz", @"x", @"y", nil])])

	TEST(@"-[removeObject:]",
	    R([mutableSet removeObject: @"y"]) && [mutableSet isEqual: set1])

	TEST(@"-[isSubsetOfSet:]",
	    R([mutableSet removeObject: @"foo"]) &&
	    [mutableSet isSubsetOfSet: set1] &&
	    ![set1 isSubsetOfSet: mutableSet]);

	TEST(@"-[intersectsSet:]",
	    [(set2 = [OFSet setWithObjects: @"x", nil]) intersectsSet: set1] &&
	    [set1 intersectsSet: set2] &&
	    ![([OFSet setWithObjects: @"1", nil]) intersectsSet: set1]);

#ifdef OF_HAVE_FAST_ENUMERATION
	ok = YES;
	i = 0;

	for (OFString *s in set1) {
		switch (i) {
		case 0:
			if (![s isEqual: @"bar"])
				ok = NO;
			break;
		case 1:
			if (![s isEqual: @"baz"])
				ok = NO;
			break;
		case 2:
			if (![s isEqual: @"foo"])
				ok = NO;
			break;
		case 3:
			if (![s isEqual: @"x"])
				ok = NO;
			break;
		}

		i++;
	}

	if (i != 4)
		ok = NO;

	TEST(@"Fast enumeration", ok)
#endif

	[pool drain];
}
@end
