//
//  BTAddressBook.m
//  dogo
//
//  Created by Marcus Westin on 2/21/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTAddressBook.h"
#import <AddressBook/AddressBook.h>

@implementation BTAddressBook

static BTAddressBook* instance;

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    [app registerHandler:@"BTAddressBook.getAllEntries" handler:^(id data, BTResponseCallback responseCallback) {
        [self _getAllEntries:data responseCallback:responseCallback];
    }];
    [app registerHandler:@"BTAddressBook.getAuthorizationStatus" handler:^(id data, BTResponseCallback responseCallback) {
        [self _getAuthorization:data responseCallback:responseCallback];
    }];
}

- (void) _getAuthorization:(NSDictionary*)data responseCallback:(BTResponseCallback)responseCallback {
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    NSString* response = nil;
    
    if (status == kABAuthorizationStatusNotDetermined) { response = @"not determined"; }
    else if (status == kABAuthorizationStatusRestricted) { response = @"restricted"; }
    else if (status == kABAuthorizationStatusDenied) { response = @"denied"; }
    else if (status == kABAuthorizationStatusAuthorized) { response = @"authorized"; }
    
    if (response) { responseCallback(nil, response); }
    else { responseCallback(@"Unknown status", nil); }
}

- (void)_getAllEntries:(NSDictionary*)data responseCallback:(BTResponseCallback)responseCallback {
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
    if (!addressBook) { return responseCallback(@"Could not open address book", nil); }
    ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
        if (!granted) { return responseCallback(@"Give Dogo access to your address book in Settings -> Privacy -> Contacts", nil); }
        if (error) { return responseCallback(CFBridgingRelease(error), nil); }
        CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(addressBook);
        CFIndex numPeople = ABAddressBookGetPersonCount(addressBook);
        NSMutableArray* entries = [NSMutableArray arrayWithCapacity:numPeople];
        NSArray* emptyArray = @[];
        for (int i=0; i<numPeople; i++ ) {
            ABRecordRef person = CFArrayGetValueAtIndex(allPeople, i);
            
            ABMultiValueRef emailProperty = ABRecordCopyValue(person, kABPersonEmailProperty);
            ABMultiValueRef phoneProperty = ABRecordCopyValue(person, kABPersonPhoneProperty);
            NSString *firstName = (__bridge NSString *)ABRecordCopyValue(person, kABPersonFirstNameProperty);
            NSString *lastName = (__bridge NSString *)ABRecordCopyValue(person, kABPersonLastNameProperty);
            NSArray *emailArray = (__bridge NSArray *)ABMultiValueCopyArrayOfAllValues(emailProperty);
            NSArray *phoneArray = (__bridge NSArray *)ABMultiValueCopyArrayOfAllValues(phoneProperty);
            
            if (!firstName) { firstName = @""; }
            if (!lastName) { lastName = @""; }
            if (!emailArray) { emailArray = emptyArray; }
            if (!phoneArray) { phoneArray = emailArray; }
            
            [entries addObject:@{ @"firstName":firstName, @"lastName":lastName, @"emails": emailArray, @"phones":phoneArray }];
        }
        CFRelease(addressBook);
        CFRelease(allPeople);
        responseCallback(nil, @{ @"entries":entries });
    });
}


@end


