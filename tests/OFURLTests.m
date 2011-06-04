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

#import "OFURL.h"
#import "OFString.h"
#import "OFAutoreleasePool.h"

#import "OFInvalidFormatException.h"

#import "TestsAppDelegate.h"

static OFString *module = @"OFURL";
static OFString *url_str = @"http://u:p@h:1234/f;p?q#f";

@implementation TestsAppDelegate (OFURLTests)
- (void)URLTests
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];
	OFURL *u1, *u2, *u3, *u4;

	TEST(@"+[URLWithString:]",
	    R(u1 = [OFURL URLWithString: url_str]) &&
	    R(u2 = [OFURL URLWithString: @"http://foo:80"]) &&
	    R(u3 = [OFURL URLWithString: @"http://bar/"]) &&
	    R(u4 = [OFURL URLWithString: @"file:///etc/passwd"]))

	TEST(@"+[URLWithString:relativeToURL:]",
	    [[[OFURL URLWithString: @"/foo"
		     relativeToURL: u1] description] isEqual:
	    @"http://u:p@h:1234/foo"] &&
	    [[[OFURL URLWithString: @"foo/bar?q"
		     relativeToURL: [OFURL URLWithString: @"http://h/qux/quux"]]
	    description] isEqual: @"http://h/qux/foo/bar?q"] &&
	    [[[OFURL URLWithString: @"foo/bar"
		     relativeToURL: [OFURL URLWithString: @"http://h/qux/?x"]]
	    description] isEqual: @"http://h/qux/foo/bar"] &&
	    [[[OFURL URLWithString: @"http://foo/?q"
		     relativeToURL: u1] description] isEqual: @"http://foo/?q"])

	TEST(@"-[description]",
	    [[u1 description] isEqual: url_str] &&
	    [[u2 description] isEqual: @"http://foo"] &&
	    [[u3 description] isEqual: @"http://bar/"] &&
	    [[u4 description] isEqual: @"file:///etc/passwd"])

	TEST(@"-[scheme]",
	    [[u1 scheme] isEqual: @"http"] && [[u4 scheme] isEqual: @"file"])
	TEST(@"-[user]", [[u1 user] isEqual: @"u"] && [u4 user] == nil)
	TEST(@"-[password]",
	    [[u1 password] isEqual: @"p"] && [u4 password] == nil)
	TEST(@"-[host]", [[u1 host] isEqual: @"h"] && [u4 port] == 0)
	TEST(@"-[port]", [u1 port] == 1234)
	TEST(@"-[path]",
	    [[u1 path] isEqual: @"/f"] && [[u4 path] isEqual: @"/etc/passwd"])
	TEST(@"-[parameters]",
	    [[u1 parameters] isEqual: @"p"] && [u4 parameters] == nil)
	TEST(@"-[query]", [[u1 query] isEqual: @"q"] && [u4 query] == nil)
	TEST(@"-[fragment]",
	    [[u1 fragment] isEqual: @"f"] && [u4 fragment] == nil)

	TEST(@"-[copy]", R(u4 = [[u1 copy] autorelease]))

	TEST(@"-[isEqual:]", [u1 isEqual: u4] && ![u2 isEqual: u3] &&
	    [[OFURL URLWithString: @"http://bar/"] isEqual: u3])

	TEST(@"-[hash:]", [u1 hash] == [u4 hash] && [u2 hash] != [u3 hash])

	EXPECT_EXCEPTION(@"Detection of invalid format",
	    OFInvalidFormatException, [OFURL URLWithString: @"http"])

	EXPECT_EXCEPTION(@"Detection of invalid scheme",
	    OFInvalidFormatException, [OFURL URLWithString: @"foo://"])

	[pool drain];
}
@end
