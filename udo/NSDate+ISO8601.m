//
//  NSDate_NSDate_ISO8601.m
//  udo
//
//  Created by Osman Alpay on 30/10/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NSDate+ISO8601.h"
#import "ISO8601DateFormatter.h"

static ISO8601DateFormatter *_iso8601DateFormatter;

@implementation NSDate (ISO8601)

+ (NSDate *)dateFromISO8601String:(NSString *)value {
    ISO8601DateFormatter* iso8601DateFormatter = [[ISO8601DateFormatter alloc] init];
    return [iso8601DateFormatter dateFromString:value];
}

@end
