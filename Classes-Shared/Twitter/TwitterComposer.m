//
//  TwitterComposer.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 8/2/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterComposer.h"
#import "TwitterAccount.h"
#import "Twitter.h"
#import "TwitterUpdateStatusAction.h"
#import "TwitterRetweetAction.h"
#import "TwitterSendDirectMessageAction.h"


@implementation TwitterComposer
@synthesize twitter, account, locationManager, actions, delegate;

+ (CLLocationManager *)createLocationManager {
	CLLocationManager *lm = nil;
	
#ifdef TARGET_PROJECT_MAC
	if ([CLLocationManager locationServicesEnabled])
		lm = [[CLLocationManager alloc] init];
#else
	lm = [[[CLLocationManager alloc] init] autorelease];
	if (lm.locationServicesEnabled == NO)
		lm = nil;
#endif
	return lm;
}

- (id)initWithTwitter:(Twitter *)aTwitter account:(TwitterAccount *)anAccount {
	self = [super init];
	if (self) {
		self.twitter = aTwitter;
		self.account = anAccount;
		self.actions = [NSMutableSet set];

		// Location
		locationManager = [[TwitterComposer createLocationManager] retain];
		locationManager.distanceFilter = 100.0; // meters
		locationManager.desiredAccuracy = 30.0; // meters
	}
	return self;
}

- (void)dealloc {
	[twitter release];
	[account release];
	[locationManager release];
	[actions release];
	[super dealloc];
}

- (NSError *)errorWithCode:(int)code description:(NSString *)desc {
	return [NSError errorWithDomain:@"com.felttip" code:code userInfo:[NSDictionary dictionaryWithObject:desc forKey:NSLocalizedDescriptionKey]];
}

#pragma mark Network actions

- (NSUInteger)numberOfNetworkActions {
	return actions.count;
}

- (void)cancelActions {
	id action;
	for (action in actions) {
		if ([action respondsToSelector:@selector(cancel)]) {
			[action cancel];
		}
	}
}


- (void)addAction:(id)anAction {
	[actions addObject:anAction];
	[delegate composerDidStartNetworkAction:self];
	[delegate retain]; // Retain delegate for each outstanding action.
}


- (void)removeAction:(id)anAction {
	[actions removeObject:anAction];
	[delegate composerDidFinishNetworkAction:self];
	[delegate release]; // Retain delegate for each outstanding action.
}

#pragma mark Twitter actions

- (void)startTwitterAction:(TwitterAction*)action {
	if (action == nil) return;
	
	// Add the action to the array of actions, and updates the network activity spinner
	[self addAction:action];
	
	// Set up Twitter action
	action.delegate = self;
	action.consumerToken = account.xAuthToken;
	action.consumerSecret = account.xAuthSecret;
	
	// Start the URL connection
	[action start];
}

- (void) twitterActionDidFinishLoading:(TwitterAction*)action {
	if (action.statusCode < 400 || action.statusCode == 403) {
		// Twitter returns 403 if a duplicate status was posted.
		[delegate composerDidFinishSendingStatusUpdate:self];
	} else { 
		// An error occurred.
		NSError *error = [self errorWithCode:action.statusCode description:NSLocalizedString(@"A network error occurred.", @"description")];
		[delegate composer:self didFailWithError:error];
	}
	[self removeAction:action];
}

- (void) twitterAction:(TwitterAction*)action didFailWithError:(NSError*)error {
	if (error.code == TwitterActionErrorCodeDirectMessageFailedNoFollow) {
		// didSendDirectMessage handles communication with delegate
		[self removeAction: action];
	} else {
		[delegate composer:self didFailWithError:error];
		[self removeAction: action];
	}
}

#pragma mark Tweeting and Retweeting

- (void)retweetMessageWithIdentifier:(NSNumber *)messageIdentifier {
	TwitterRetweetAction *action = [[[TwitterRetweetAction alloc] initWithMessageIdentifier:messageIdentifier] autorelease];
	[self startTwitterAction:action];
}	

- (void)updateStatus:(NSString *)text inReplyTo:(NSNumber *)reply location:(CLLocation *)location {
	TwitterUpdateStatusAction *action = [[[TwitterUpdateStatusAction alloc] initWithText:text inReplyTo:reply] autorelease];
	[action setLocation:location];
	[self startTwitterAction:action];
}

- (void)sendDirectMessage:(NSString *)text to:(NSString*)screenName {
	TwitterSendDirectMessageAction *action = [[[TwitterSendDirectMessageAction alloc] initWithText:text to:screenName] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didSendDirectMessage:);
	[self startTwitterAction:action];
}

#pragma mark URL shortening

- (void)shrinkURLsInString:(NSString *)string {
	NSSet *shrinkActions = [LKShrinkURLAction actionsToShrinkURLsInString:string];
	
	if (shrinkActions.count > 0) {
		for (LKShrinkURLAction *action in shrinkActions) {
			action.delegate = self;
			[action load];
			[self addAction:action];
		}
	}
}

- (void)action:(LKShrinkURLAction *)anAction didReplaceLongURL:(NSString *)longURL withShortURL:(NSString *)shortURL {
	if (longURL != nil) {
		if ([shortURL hasPrefix:@"http"]) {
			[delegate composer:self didShrinkLongURL:longURL toShortURL:shortURL];
		} else {
			// Log the error message
			NSError *error = [self errorWithCode:-1 description:@"is.gd returned an error."];
			[delegate composer:self didFailWithError:error];
		}
	}
	[self removeAction:anAction];
}

- (void)action:(id)anAction didFailWithError:(NSError*)error {
	[delegate composer:self didFailWithError:error];
	[self removeAction:anAction];
}

#pragma mark Picture uploading

- (void)uploadPicture:(NSData *)picture withFileExtension:(NSString *)ext {
	// Create and start action.
	LKUploadPictureAction *action = [[[LKUploadPictureAction alloc] initWithPicture:picture fileExtension:ext] autorelease];
	action.delegate = self;
	action.username = account.screenName;
	action.password = account.password;
	if (action.password != nil) {
		[action startUpload];
		[self addAction:action];
	} else {
		NSError *error = [self errorWithCode:-1 description:@"Password required to upload pictures."];
		[delegate composer:self didFailWithError:error];
	}
}

- (void)action:(LKUploadPictureAction *)action didUploadPictureWithURL:(NSString *)url {
	[delegate composer:self didUploadPictureWithURL:url];
	[self removeAction:action];
}

- (void)didSendDirectMessage:(TwitterSendDirectMessageAction*)action {
	if (action.twitterAPIError)
		[self.delegate composerDidFailSendingDirectMessage:self error:action.twitterAPIError];
	else {
		[self.delegate composerDidFinishSendingDirectMessage:self];
	}
}


@end
