//
//  GBPing.h
//  GBPing
//
//  Created by Luka Mirosevic on 05/11/2012.
//  Copyright (c) 2012 Goonbee. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SimplePing.h"

@class GBPingSummary;
@protocol GBPingDelegate;

typedef void(^StartupCallback)(BOOL success, NSError *error);

@interface GBPing : NSObject <SimplePingDelegate>

@property (weak, nonatomic) id<GBPingDelegate>      delegate;

@property (copy, nonatomic) NSString                *host;
@property (assign, nonatomic) NSTimeInterval        pingPeriod;
@property (assign, nonatomic) NSTimeInterval        timeout;
@property (assign, nonatomic) NSUInteger            payloadSize;
@property (assign, nonatomic) NSUInteger            ttl;
@property (assign, atomic, readonly) BOOL        isPinging;

-(void)setup;//get rid of this
-(void)start;//add a startup callback to this
-(void)stop;

@end

@protocol GBPingDelegate <NSObject>

@optional

-(void)pingDidSuccessfullySetup:(GBPing *)pinger;
-(void)ping:(GBPing *)pinger didFailWithError:(NSError *)error;

-(void)ping:(GBPing *)pinger didSendPingToHost:(NSString *)host withSequenceNumber:(NSUInteger)sequenceNumber;
-(void)ping:(GBPing *)pinger didFailToSendPingToHost:(NSString *)host withSequenceNumber:(NSUInteger)sequenceNumber;
-(void)ping:(GBPing *)pinger didTimeoutWithSummary:(GBPingSummary *)summary;
-(void)ping:(GBPing *)pinger didReceiveReplyWithSummary:(GBPingSummary *)summary;
-(void)ping:(GBPing *)pinger didReceiveUnexpectedReplyWithSummary:(GBPingSummary *)summary;

@end