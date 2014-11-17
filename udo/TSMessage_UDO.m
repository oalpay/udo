//
//  TSMessage_UDO.m
//  udo
//
//  Created by Osman Alpay on 17/11/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TSMessage_UDO.h"

@implementation TSMessage (UDO)

+ (void)showNotificationWithTitle:(NSString *)title
                             type:(TSMessageNotificationType)type
                         duration:(NSTimeInterval)duration
                         callback:(void (^)())callback
{
    [self showNotificationInViewController:[self defaultViewController]
                                     title:title
                                  subtitle:nil
                                     image:nil
                                      type:type
                                  duration:duration
                                  callback:callback
                               buttonTitle:nil
                            buttonCallback:nil
                                atPosition:TSMessageNotificationPositionTop
                      canBeDismissedByUser:YES];
    
}

@end
