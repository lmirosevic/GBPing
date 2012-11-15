//
//  GBPing.h
//  GBPing
//
//  Created by Luka Mirosevic on 05/11/2012.
//  Copyright (c) 2012 Goonbee. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GBPingSummary;
@protocol GBPingDelegate;

typedef void(^StartupCallback)(BOOL success, NSError *error);

@interface GBPing : NSObject

@property (weak, nonatomic) id<GBPingDelegate>      delegate;

@property (copy, nonatomic) NSString                *host;
@property (assign, nonatomic) NSTimeInterval        pingPeriod;
@property (assign, nonatomic) NSTimeInterval        timeout;
@property (assign, nonatomic) NSUInteger            payloadSize;
@property (assign, nonatomic) NSUInteger            ttl;
@property (assign, atomic, readonly) BOOL           isPinging;
@property (assign, atomic, readonly) BOOL           isReady;

-(void)setupWithBlock:(StartupCallback)callback;
-(void)startPinging;
-(void)stop;

@end

@protocol GBPingDelegate <NSObject>

@optional

-(void)ping:(GBPing *)pinger didFailWithError:(NSError *)error;

-(void)ping:(GBPing *)pinger didSendPingWithSummary:(GBPingSummary *)summary;
-(void)ping:(GBPing *)pinger didFailToSendPingWithSummary:(GBPingSummary *)summary;
-(void)ping:(GBPing *)pinger didTimeoutWithSummary:(GBPingSummary *)summary;
-(void)ping:(GBPing *)pinger didReceiveReplyWithSummary:(GBPingSummary *)summary;
-(void)ping:(GBPing *)pinger didReceiveUnexpectedReplyWithSummary:(GBPingSummary *)summary;

@end