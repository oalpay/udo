//
//  APAddressBook_UDO.m
//  udo
//
//  Created by Osman Alpay on 17/11/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "APAddressBook_UDO.h"
#import <AddressBook/AddressBook.h>

@implementation APAddressBook (UDO)

- (void) requestAccess:(void (^)(bool granted,NSError *error))callbackBlock{
    ABAddressBookRequestAccessWithCompletion(self.addressBook, ^(bool granted, CFErrorRef errorRef){
        callbackBlock(granted,(__bridge NSError *)errorRef);
    });
}

@end
