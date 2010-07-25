HelTweetica
by
Lucius Kwok (project manager, lead developer, UI designer)
Thomas Alvarez (developer)
Jeff Soto (developer)

The official repository for HelTweetica is at github: http://github.com/luciuskwok/HelTweetica

----------
About HelTweetica

HelTweetica is an iPad app that uses xAuth (OAuth variant) and JSON to read, star, retweet, and post tweets from multiple Twitter accounts.

----------
How to build HelTweetica

Before you can build this project, you need to have your own OAuth Consumer Key and Consumer Secret, which you can get from Twitter:

http://twitter.com/oauth_clients/new

You will also want to use the xAuth authentication method (which bypasses the usual OAuth practice of requiring users to auth through a web browser), which requires sending an email to Twitter making the request:

http://apiwiki.twitter.com/Twitter-REST-API-Method:-oauth-access_token-for-xAuth

Then in Twitter.m, put your key and secret in:

#define kConsumerKey @"xxxxxxxxxxxxxxxx"
#define kConsumerSecret @"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

----------
Legal

 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

----------

-Lucius Kwok <lucius.kwok@gmail.com>
April 26, 2010

