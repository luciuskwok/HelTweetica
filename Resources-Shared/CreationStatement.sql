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
	createdAt integer, 
	updatedAt integer, 
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
	retweetedMessageIdentifier integer,
	createdAt integer,
	receivedAt integer,
	locked boolean
);

CREATE TABLE DirectMessages (
	identifier integer primary key,
	createdAt integer,
	receivedAt integer,
	senderIdentifier integer,
	senderScreenName text,
	recipientIdentifier integer,
	recipientScreenName text,
	locked boolean,
	text text
);
