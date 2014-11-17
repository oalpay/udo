//
//  APAddressBook_UDO.h
//  udo
//
//  Created by Osman Alpay on 17/11/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

#import "APAddressBook.h"

@interface APAddressBook (UDO)
- (void) requestAccess:(void (^)(bool granted,NSError *error))callbackBlock;
@end
