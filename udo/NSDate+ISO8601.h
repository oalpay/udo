//
//  NSDate_NSDate_ISO8601.h
//  udo
//
//  Created by Osman Alpay on 30/10/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (ISO8601)

+ (NSDate *)dateFromISO8601String:(NSString *)iso8601String;

@end