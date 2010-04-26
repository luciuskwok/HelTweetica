//
//  SoundEffects.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/18/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SoundEffects.h"

@interface SoundEffects (PrivateMethods)
- (SystemSoundID) createSoundWithName: (NSString*) name;
@end


@implementation SoundEffects

+ (SoundEffects*) sharedSoundEffects {
	static SoundEffects *_sharedSoundEffects = nil;
	if (_sharedSoundEffects == nil) {
		_sharedSoundEffects = [[SoundEffects alloc] init];
	}
	return _sharedSoundEffects;
}

- (id) init {
	self = [super init];
	if (self) {
		// Configure properties on the audio session
		NSError *audioError = nil;
		[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&audioError];		
		if (audioError) NSLog(@"AVAudioSession setCategory error: %@", audioError);
		
		// If the audio session is changed to AVAudioSessionCategoryPlayback, then we also need to explicitly allow app audio to mix with other audio by setting the kAudioSessionProperty_OverrideCategoryMixWithOthers property to true.
		UInt32 trueValue = 1;
		OSStatus err = AudioSessionSetProperty( kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof(trueValue), &trueValue);
		if (err) NSLog(@"AVAudioSession set property mix with others: %d", err);
		
		showMessageSound = [self createSoundWithName:@"showMessageSound"];
		selectMessageSound = [self createSoundWithName:@"selectMessageSound"];
	}
	return self;
}

- (void) dealloc { // Never dealloc'd
	[super dealloc];
}

- (void) playShowMessageSound {
	AudioServicesPlaySystemSound (showMessageSound);
}

- (void) playSelectMessageSound {
	AudioServicesPlaySystemSound (selectMessageSound);
}

- (SystemSoundID) createSoundWithName: (NSString*) name {
	SystemSoundID soundID = -1;
	
	NSString *path =[[NSBundle mainBundle] pathForResource:name ofType:@"caf"];
	if (path != nil) {
		NSURL *url = [NSURL fileURLWithPath:path];
		if (url != nil) {
			OSStatus err = AudioServicesCreateSystemSoundID ((CFURLRef) url, &soundID);
			if (err) NSLog (@"AudioServicesCreateSystemSoundID error %d", err);
			
			// Set property
			UInt32 value = 1; // is always UI sound effect
			AudioServicesSetProperty (kAudioServicesPropertyIsUISound, 0, nil, sizeof(value), &value);
			// Ignore this error.
			// if (err) NSLog (@"AudioServicesSetProperty(kAudioServicesPropertyIsUISound) error %d", err);
		}
	}
	return soundID;
}

@end
