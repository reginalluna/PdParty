/*
 * Copyright (c) 2013 Dan Wilcox <danomatika@gmail.com>
 *
 * BSD Simplified License.
 * For information on usage and redistribution, and for a DISCLAIMER OF ALL
 * WARRANTIES, see the file, "LICENSE.txt," in this distribution.
 *
 * See https://github.com/danomatika/PdParty for documentation
 *
 */
#import "Widget.h"

@interface Taplist : Widget

/// list of string items
@property (strong, nonatomic) NSMutableArray *list;

/// set list receive name, essentially self.receiveName + "-list"
@property (readonly, strong, nonatomic) NSString *listReceiveName;

@end
