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
    [app handleCommand:@"BTAddressBook.authorize" handler:^(id params, BTCallback callback) {
        ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
        if (!addressBook) { return callback(@"Could not open address book", nil); }
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
            if (error) { return callback((__bridge id)(error), nil); }
            return callback(nil, @{ @"granted":[NSNumber numberWithBool:granted] });
        });
    }];
    [app handleCommand:@"BTAddressBook.getAllEntries" handler:^(id data, BTCallback callback) {
        [self getAllEntries:data callback:callback];
    }];
    [app handleCommand:@"BTAddressBook.getAuthorizationStatus" handler:^(id data, BTCallback responseCallback) {
        [self _getAuthorization:data responseCallback:responseCallback];
    }];
    [app handleCommand:@"BTAddressBook.countAllEntries" handler:^(id params, BTCallback callback) {
        [self countAllEntries:params callback:callback];
    }];
    [app handleRequests:@"BTAddressBook/image" handler:^(NSDictionary *params, WVPResponse *response) {
        [self getImage:params[@"recordId"] response:response];
    }];
}

- (void) countAllEntries:(NSDictionary*)params callback:(BTCallback)callback {
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
    if (!addressBook) { return callback(@"Could not open address book", nil); }
    ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
        if (!granted) { return callback(@"Give Dogo access to your address book in Settings -> Privacy -> Contacts", nil); }
        if (error) { return callback(CFBridgingRelease(error), nil); }
        CFIndex count = ABAddressBookGetPersonCount(addressBook);
        callback(nil, @{ @"count":[NSNumber numberWithLong:count] });
    });
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

- (void) _getAuthorization:(NSDictionary*)data responseCallback:(BTCallback)responseCallback {
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    NSString* response = nil;
    
    if (status == kABAuthorizationStatusNotDetermined) { response = @"not determined"; }
    else if (status == kABAuthorizationStatusRestricted) { response = @"restricted"; }
    else if (status == kABAuthorizationStatusDenied) { response = @"denied"; }
    else if (status == kABAuthorizationStatusAuthorized) { response = @"authorized"; }
    
    if (response) { responseCallback(nil, response); }
    else { responseCallback(@"Unknown status", nil); }
}

+ (void)allEntries:(BTCallback)callback {
    [instance getAllEntries:nil callback:callback];
}

- (void)getAllEntries:(NSDictionary*)data callback:(BTCallback)callback {
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
    if (!addressBook) { return callback(@"Could not open address book", nil); }
    ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
        if (!granted) { return callback(@"Give Dogo access to your address book in Settings -> Privacy -> Contacts", nil); }
        if (error) { return callback(CFBridgingRelease(error), nil); }
        NSNumber* indexNum = data[@"index"];
        NSNumber* limitNum = data[@"limit"];
        CFIndex index = (indexNum ? [indexNum longValue] : 0);
        CFIndex numPeople = ABAddressBookGetPersonCount(addressBook);
        CFIndex limit = (limitNum ? [limitNum longValue] : 0);
        if (index + limit > numPeople) { limit = numPeople - index; }
        
        CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(addressBook);
        NSMutableArray* entries = [NSMutableArray arrayWithCapacity:limit];
        NSArray* emptyArray = @[];
        for (int i=index; i<index+limit; i++ ) {
            ABRecordRef person = CFArrayGetValueAtIndex(allPeople, i);
            
            NSString *firstName = (__bridge NSString *)ABRecordCopyValue(person, kABPersonFirstNameProperty);
            NSString *lastName = (__bridge NSString *)ABRecordCopyValue(person, kABPersonLastNameProperty);
            NSNumber* hasImage = [NSNumber numberWithBool:ABPersonHasImageData(person)];
            NSString* recordId = [NSString stringWithFormat:@"%d", ABRecordGetRecordID(person)];

            ABMultiValueRef emailProperty = ABRecordCopyValue(person, kABPersonEmailProperty);
            NSArray *emailArray = (__bridge NSArray *)ABMultiValueCopyArrayOfAllValues(emailProperty);
            if (!emailArray) { emailArray = emptyArray; }

            ABMultiValueRef phoneProperty = ABRecordCopyValue(person, kABPersonPhoneProperty);
            NSArray *phoneArray = (__bridge NSArray *)ABMultiValueCopyArrayOfAllValues(phoneProperty);
            if (!phoneArray) { phoneArray = emptyArray; }
            
            NSDate* birthdayDate = (__bridge NSDate *)ABRecordCopyValue(person, kABPersonBirthdayProperty);
            NSArray* birthday = nil;
            if (birthdayDate) {
                NSDateComponents *components = [[NSCalendar currentCalendar] components:NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate:birthdayDate];
                birthday = @[
                             [NSNumber numberWithInt:[components day]],
                             [NSNumber numberWithInt:[components month]],
                             [NSNumber numberWithInt:[components year]]];
            }
            
            
            [entries addObject:@{ @"recordId":recordId, @"firstName":firstName, @"lastName":lastName, @"emailAddresses":emailArray, @"phoneNumbers":phoneArray, @"hasImage":hasImage, @"birthday":birthday }];
        }
        CFRelease(addressBook);
        CFRelease(allPeople);
        callback(nil, @{ @"entries":entries });
    });
}

- (void)getMedia:(NSString *)mediaId callback:(BTCallback)callback {
    NSData* data = [self _getImage:[mediaId intValue]];
    callback(data ? nil : @"Could not get address book image", data);
}


@end


