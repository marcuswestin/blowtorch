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
    instance = self;
    [app registerHandler:@"BTAddressBook.getAllEntries" handler:^(id data, BTResponseCallback callback) {
        [self getAllEntries:data callback:callback];
    }];
    [app registerHandler:@"BTAddressBook.getAuthorizationStatus" handler:^(id data, BTResponseCallback responseCallback) {
        [self _getAuthorization:data responseCallback:responseCallback];
    }];
    [app handleRequests:@"BTAddressBook/image" handler:^(NSDictionary *params, WVPResponse *response) {
        [self getImage:params[@"recordId"] response:response];
    }];
}

- (void) getImage:(NSString*)recordId response:(WVPResponse*)response {
    NSData* data = [self _getImage:[recordId intValue]];
    if (data) {
        UIImage* image = [UIImage imageWithData:data];
        [response respondWithImage:image];
    } else {
        [response respondWithError:400 text:@"BTAddressBook image not found"];
    }
}

- (NSData*) _getImage:(ABRecordID)recordId {
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
    if (!addressBook) { return nil; }
    ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, recordId);
    return (__bridge NSData *)(ABPersonCopyImageData(person));
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

+ (void)allEntries:(BTResponseCallback)callback {
    [instance getAllEntries:nil callback:callback];
}

- (void)getAllEntries:(NSDictionary*)data callback:(BTResponseCallback)callback {
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
    if (!addressBook) { return callback(@"Could not open address book", nil); }
    ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
        if (!granted) { return callback(@"Give Dogo access to your address book in Settings -> Privacy -> Contacts", nil); }
        if (error) { return callback(CFBridgingRelease(error), nil); }
        CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(addressBook);
        CFIndex numPeople = ABAddressBookGetPersonCount(addressBook);
        NSMutableArray* entries = [NSMutableArray arrayWithCapacity:numPeople];
        NSArray* emptyArray = @[];
        for (int i=0; i<numPeople; i++ ) {
            ABRecordRef person = CFArrayGetValueAtIndex(allPeople, i);
            
            NSString *firstName = (__bridge NSString *)ABRecordCopyValue(person, kABPersonFirstNameProperty);
            NSString *lastName = (__bridge NSString *)ABRecordCopyValue(person, kABPersonLastNameProperty);
            NSNumber* hasImage = [NSNumber numberWithBool:ABPersonHasImageData(person)];
            NSString* recordId = [NSString stringWithFormat:@"%d", ABRecordGetRecordID(person)];
            NSString* name = nil;
            if (firstName) {
                if (lastName) { name = [NSString stringWithFormat:@"%@ %@", firstName, lastName]; }
                else { name = firstName; }
            } else {
                name = @"";
            }

            ABMultiValueRef emailProperty = ABRecordCopyValue(person, kABPersonEmailProperty);
            NSArray *emailArray = (__bridge NSArray *)ABMultiValueCopyArrayOfAllValues(emailProperty);
            if (!emailArray) { emailArray = emptyArray; }

            ABMultiValueRef phoneProperty = ABRecordCopyValue(person, kABPersonPhoneProperty);
            NSArray *phoneArray = (__bridge NSArray *)ABMultiValueCopyArrayOfAllValues(phoneProperty);
            if (!phoneArray) { phoneArray = emptyArray; }
            
            [entries addObject:@{ @"recordId":recordId, @"name":name, @"emailAddresses":emailArray, @"phoneNumbers":phoneArray, @"hasImage":hasImage }];
        }
        CFRelease(addressBook);
        CFRelease(allPeople);
        callback(nil, @{ @"entries":entries });
    });
}

- (void)getMedia:(NSString *)mediaId callback:(BTResponseCallback)callback {
    NSData* data = [self _getImage:[mediaId intValue]];
    callback(data ? nil : @"Could not get address book image", data);
}


@end


