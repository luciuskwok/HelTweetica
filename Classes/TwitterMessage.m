//
//  Message.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/1/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "TwitterMessage.h"


#define kAvatarSize 256.0f


@implementation TwitterMessage
@synthesize identifier, inReplyToStatusIdentifier, inReplyToUserIdentifier;
@synthesize screenName, inReplyToScreenName, avatar, content, source, retweetedMessage;
@synthesize createdDate, receivedDate, largeAvatar;
@synthesize locked, favorite, direct;
@synthesize downloadConnection, downloadData;


- (void) dealloc {
	[identifier release];
	[inReplyToStatusIdentifier release];
	[inReplyToUserIdentifier release];
	[screenName release];
	[inReplyToScreenName release];
	[avatar release];
	[content release];
	[source release];
	[retweetedMessage release];
	[createdDate release];
	[receivedDate release];
	[largeAvatar release];
	
	[downloadConnection release];
	[downloadData release];
	
	[super dealloc];
}

- (id) initWithCoder: (NSCoder*) decoder {
	if (self = [super init]) {
		self.identifier = [decoder decodeObjectForKey:@"identifier"];
		self.inReplyToStatusIdentifier = [decoder decodeObjectForKey:@"inReplyToStatusIdentifier"];
		self.inReplyToUserIdentifier = [decoder decodeObjectForKey:@"inReplyToUserIdentifier"];
		
		self.screenName = [decoder decodeObjectForKey:@"username"];
		self.inReplyToScreenName = [decoder decodeObjectForKey:@"inReplyToScreenName"];
		self.avatar = [decoder decodeObjectForKey:@"avatar"];
		self.content = [decoder decodeObjectForKey:@"content"];
		self.source = [decoder decodeObjectForKey:@"source"];
		self.retweetedMessage = [decoder decodeObjectForKey:@"retweetedMessage"];
		
		self.createdDate = [decoder decodeObjectForKey:@"date"];
		self.receivedDate = [decoder decodeObjectForKey:@"receivedDate"];
		
		locked = [decoder decodeBoolForKey:@"locked"];
		favorite = [decoder decodeBoolForKey:@"favorite"];
		direct = [decoder decodeBoolForKey:@"direct"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject: identifier forKey:@"identifier"];
	[encoder encodeObject: inReplyToStatusIdentifier forKey:@"inReplyToStatusIdentifier"];
	[encoder encodeObject: inReplyToUserIdentifier forKey:@"inReplyToUserIdentifier"];

	[encoder encodeObject:screenName forKey:@"username"];
	[encoder encodeObject:inReplyToScreenName forKey:@"inReplyToScreenName"];
	[encoder encodeObject:avatar forKey:@"avatar"];
	[encoder encodeObject:content forKey:@"content"];
	[encoder encodeObject:source forKey:@"source"];
	[encoder encodeObject:retweetedMessage forKey:@"retweetedMessage"];
	
	[encoder encodeObject:createdDate forKey:@"date"];
	[encoder encodeObject:receivedDate forKey:@"receivedDate"];
	
	[encoder encodeBool:locked forKey:@"locked"];
	[encoder encodeBool:favorite forKey:@"favorite"];
	[encoder encodeBool:direct forKey:@"direct"];
}

- (SInt64) identifierInt64 {
	return [self.identifier longLongValue];
}

- (void) setIdentifierInt64:(SInt64)x {
	self.identifier = [NSNumber numberWithLongLong:x];
}

- (NSString*) layoutSafeContent {
	NSMutableString *s = [NSMutableString stringWithString: self.content];
	NSString *usernameText, *insertText, *urlText, *linkText;
	
	// Find URLs beginning with http: https*://[^ \t\r\n\v\f]*
	NSRange unprocessed, foundRange;
	unprocessed = NSMakeRange(0, [s length]);
	while (unprocessed.location < [s length]) {
		foundRange = [s rangeOfString: @"https*://[^ \t\r\n]*" options: NSRegularExpressionSearch range: unprocessed];
		if (foundRange.location == NSNotFound) break;
		
		// Replace URLs with link text
		urlText = [s substringWithRange: foundRange];
		linkText = [urlText substringFromIndex: [urlText hasPrefix:@"https"] ? 8 : 7];
		if ([linkText length] > 29) {
			linkText = [NSString stringWithFormat: @"%@...", [linkText substringToIndex:26]];
			insertText = [NSString stringWithFormat: @"<a href='%@'>%@</a>", urlText, linkText];
		} else {	
			insertText = [NSString stringWithFormat: @"<a href='%@'>%@</a>", urlText, linkText];
		}
		[s replaceCharactersInRange: foundRange withString: insertText];
		
		unprocessed.location = foundRange.location + [insertText length];
		unprocessed.length = [s length] - unprocessed.location;
	}
		
	// Find @usernames: @([A-Za-z0-9_]*) 
	unprocessed = NSMakeRange(0, [s length]);
	while (unprocessed.location < [s length]) {
		// TODO: Should ignore @ inside of html tags, or above should url-encode @ symbols.
		foundRange = [s rangeOfString: @"@[A-Za-z0-9_]*" options: NSRegularExpressionSearch range: unprocessed];
		if (foundRange.location == NSNotFound) break;

		usernameText = [s substringWithRange: NSMakeRange (foundRange.location + 1, foundRange.length - 1)];
		insertText = [NSString stringWithFormat: @"@<a href='action:user/%@'>%@</a>", usernameText, usernameText];
		[s replaceCharactersInRange: foundRange withString: insertText];
		
		unprocessed.location = foundRange.location + [insertText length];
		unprocessed.length = [s length] - unprocessed.location;
	}
	
	// Replace newlines and carriage returns with <br>
	[s replaceOccurrencesOfString:@"\r\n" withString:@"<br>" options:0 range:NSMakeRange(0, [s length])];
	[s replaceOccurrencesOfString:@"\n" withString:@"<br>" options:0 range:NSMakeRange(0, [s length])];
	[s replaceOccurrencesOfString:@"\r" withString:@"<br>" options:0 range:NSMakeRange(0, [s length])];

	// Remove NULs
	[s replaceOccurrencesOfString:@"\0" withString:@"" options:0 range:NSMakeRange(0, [s length])];

	// Break up long words with soft hyphens
	unprocessed = NSMakeRange(0, [s length]);
	while (unprocessed.location < [s length]) {
		foundRange = [s rangeOfString: @"[A-Za-z0-9]{46,46}" options: NSRegularExpressionSearch range: unprocessed];
		if (foundRange.location == NSNotFound) break;
		
		// Insert soft hyphen after 40 chars
		[s replaceCharactersInRange: NSMakeRange(foundRange.location + foundRange.length, 0) withString:@"&shy;"];
		
		unprocessed.location = foundRange.location + foundRange.length + 5;
		unprocessed.length = [s length] - unprocessed.location;
	}
	//[s replaceOccurrencesOfString:@"/" withString:@"/&shy;" options:0 range:NSMakeRange(0, [s length])];
	
	return s;
}

// description: for the debugger po command.
- (NSString*) description {
	NSMutableString *result = [NSMutableString string];
	if (screenName != nil) 
		[result appendFormat:@"%@: ", screenName];
	if (content != nil) 
		[result appendString: content];
	return result;
}

// hash and isEqual: are used by NSSet to determine if an object is unique.
- (NSUInteger) hash {
	return [identifier hash];
}

- (BOOL) isEqual:(id)object {
	BOOL result = NO;
	if ([object respondsToSelector:@selector(identifier)]) {
		result = [self.identifier isEqual: [object identifier]];
	}
	return result;
}

- (void) loadLargeAvatar {
	NSString *largeImageURLString = [self.avatar stringByReplacingOccurrencesOfString:@"_normal" withString:@""];
	NSURL *url = [NSURL URLWithString:largeImageURLString];
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:url] autorelease];
	//[request setHTTPMethod:@"GET"];
	
	// Create the download connection
	//[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	self.downloadConnection = [[[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately: YES] autorelease];
	isLoading = YES;
	
}

- (UIImage*) resizeImage:(UIImage*)originalImage withSize:(CGSize)newSize {
	CGSize originalSize = originalImage.size;
	CGFloat originalAspectRatio = originalSize.width / originalSize.height;
	
	CGImageRef cgImage = nil;
	int bitmapWidth = newSize.width;
	int bitmapHeight = newSize.height;
	CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(nil, bitmapWidth, bitmapHeight, 8, bitmapWidth * 4, colorspace, kCGImageAlphaPremultipliedLast);
	if (context != nil) {
		// Flip the coordinate system
		//CGContextScaleCTM(context, 1.0, -1.0);
		//CGContextTranslateCTM(context, 0.0, -bitmapHeight);
		
		// Black background
		CGRect rect = CGRectMake(0, 0, bitmapWidth, bitmapHeight);
		CGContextSetRGBFillColor (context, 0, 0, 0, 1);
		CGContextFillRect (context, rect);
		
		// Resize box to maintain aspect ratio
		if (originalAspectRatio < 1.0) {
			rect.origin.y += (rect.size.height - rect.size.width / originalAspectRatio) * 0.5;
			rect.size.height = rect.size.width / originalAspectRatio;
		} else {
			rect.origin.x += (rect.size.width - rect.size.height * originalAspectRatio) * 0.5;
			rect.size.width = rect.size.height * originalAspectRatio;
		}
		
		CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
		
		// Draw image
		CGContextDrawImage (context, rect, [originalImage CGImage]);
		
		// Get image
		cgImage = CGBitmapContextCreateImage (context);
		
		// Release context
		CGContextRelease(context);
	}
	CGColorSpaceRelease(colorspace);
	
	UIImage *result = [UIImage imageWithCGImage:cgImage];
	CGImageRelease (cgImage);
	return result;
}

#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	if ([response isKindOfClass: [NSHTTPURLResponse class]]) {
		downloadStatusCode = [(NSHTTPURLResponse*) response statusCode];
	}
	
	if (downloadData == nil) {
		self.downloadData = [NSMutableData data];
	} else {
		NSMutableData *theData = self.downloadData;
		[theData setLength:0];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[self.downloadData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	if (connection != downloadConnection) return;
	
	self.downloadConnection = nil;
	self.downloadData = nil;
	isLoading = NO;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	if (connection != downloadConnection) return;
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	UIImage *avatarImage = [[[UIImage alloc] initWithData:downloadData] autorelease];
	if (avatarImage != nil) {
		CGSize imageSize = avatarImage.size;
		if ((imageSize.width > kAvatarSize) || (imageSize.height > kAvatarSize)) {
			avatarImage = [self resizeImage:avatarImage withSize:CGSizeMake(kAvatarSize, kAvatarSize)];
		}
		self.largeAvatar = avatarImage;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"largeAvatarDidLoad" object:self];
	}
	self.downloadConnection = nil;
	self.downloadData = nil;
	[pool release];
}	

@end
