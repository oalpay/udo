//
//  TSMessage_UDO.h
//  udo
//
//  Created by Osman Alpay on 17/11/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

#import "TSMessage.h"

@interface TSMessage (UDO)
+ (void)showNotificationWithTitle:(NSString *)message
                             type:(TSMessageNotificationType)type
                        duration:(NSTimeInterval)duration
                         callback:(void (^)())callback;
@end
