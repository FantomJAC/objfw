/*
 * Copyright (c) 2008 - 2010
 *   Jonathan Schleifer <js@webkeks.org>
 *
 * All rights reserved.
 *
 * This file is part of ObjFW. It may be distributed under the terms of the
 * Q Public License 1.0, which can be found in the file LICENSE included in
 * the packaging of this file.
 */

#import "OFDictionary.h"

#ifdef OF_HAVE_BLOCKS
typedef id (^of_dictionary_replace_block_t)(id key, id obj, BOOL *stop);
#endif

/**
 * \brief A class for using mutable hash tables.
 */
@interface OFMutableDictionary: OFDictionary
{
	unsigned long mutations;
}

/**
 * Sets an object for a key.
 * A key can be any object.
 *
 * \param key The key to set
 * \param obj The object to set the key to
 */
- (void)setObject: (id)obj
	   forKey: (id <OFCopying>)key;

/**
 * Remove the object with the given key from the dictionary.
 *
 * \param key The key whose object should be removed
 */
- (void)removeObjectForKey: (id)key;

#ifdef OF_HAVE_BLOCKS
/**
 * Replaces each object with the object returned by the block.
 *
 * \param block The block which returns a new object for each object
 */
- (void)replaceObjectsUsingBlock: (of_dictionary_replace_block_t)block;
#endif
@end
