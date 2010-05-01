//
//  TwitterLoginAction.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/1/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TwitterAction.h"


@interface TwitterLoginAction : TwitterAction {
	NSString *username;
	NSString *password;
	NSString *token;
	NSString *secret;
}
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;
@property (nonatomic, retain) NSString *token;
@property (nonatomic, retain) NSString *secret;

- (id) initWithUsername:(NSString*)aUsername password:(NSString*)aPassword;

@end
