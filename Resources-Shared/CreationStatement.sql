CREATE TABLE Users (
	identifier integer primary key,
	screenName text, 
	fullName text, 
	bio text,
	location text, 
	profileImageURL text,
	webURL text, 
	friendsCount integer,
	followersCount integer, 
	statusesCount integer, 
	favoritesCount integer, 
	createdDate integer, 
	updatedDate integer, 
	locked boolean, 
	verified boolean
);

CREATE TABLE StatusUpdates (
	identifier integer primary key,
	userIdentifier integer,
	userScreenName text,
	profileImageURL text,
	inReplyToStatusIdentifier integer,
	inReplyToUserIdentifier integer,
	inReplyToScreenName text,
	text text,
	source text,
	retweetedStatusIdentifier integer,
	createdDate integer,
	receivedDate integer,
	locked boolean
);

CREATE TABLE DirectMessages (
	identifier integer primary key,
	createdDate integer,
	receivedDate integer,
	senderIdentifier integer,
	senderScreenName text,
	recipientIdentifier integer,
	recipientScreenName text,
	locked boolean,
	text text
);
