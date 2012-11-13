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

@interface GBPing : NSObject <SimplePingDelegate>

@property (nonatomic, weak) id<GBPingDelegate>      delegate;

@property (copy, nonatomic) NSString                *host;
@property (assign, nonatomic) NSTimeInterval        pingPeriod;
@property (assign, nonatomic) NSUInteger            packetSize;
@property (assign, nonatomic) NSUInteger            ttl;
@property (assign, nonatomic, readonly) BOOL        isPinging;

-(void)start;
-(void)stop;

@end

@protocol GBPingDelegate <NSObject>

-(void)ping:(GBPing *)pinger didSendPingToHost:(NSString *)host withSequenceNumber:(NSUInteger)sequenceNumber;
-(void)ping:(GBPing *)pinger didReceiveReplyWithSummary:(GBPingSummary *)summary fromHost:(NSString *)host;

@end