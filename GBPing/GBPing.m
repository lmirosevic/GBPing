//
//  GBPing.m
//  GBPing
//
//  Created by Luka Mirosevic on 05/11/2012.
//  Copyright (c) 2012 Goonbee. All rights reserved.
//

#define kDefaultPacketSize 64
#define kDefaultTTL 49
#define kDefaultPingPeriod 1
#define kDefaultTimeout 2

#import "GBPing.h"

#import "GBPingSummary.h"

@interface GBPing ()

@property (nonatomic, strong) SimplePing *simplePing;
@property (nonatomic, readwrite) BOOL isPinging;
@property (nonatomic, strong) NSTimer *pingTimer;
@property (nonatomic) NSUInteger nextSequenceNumber;
@property (nonatomic, strong) NSMutableDictionary *pendingPings;
@property (nonatomic, strong) NSMutableDictionary *timeoutTimers;

@end

@implementation GBPing

@synthesize packetSize = _packetSize;
@synthesize ttl = _ttl;
@synthesize timeout = _timeout;

#pragma mark - custom acc

//-(NSMutableDictionary *)pendingPings {
//    if (!_pendingPings) {
//        _pendingPings = [[NSMutableDictionary alloc] init];
//    }
//    
//    return _pendingPings;
//}

-(NSTimeInterval)timeout {
    if (!_timeout) {
        return kDefaultTimeout;
    }
    else {
        return _timeout;
    }
}

-(void)setTimeout:(NSTimeInterval)timeout {
    _timeout = timeout;//foo might need some sort of reset, at least for the timers
}

-(void)setTtl:(NSUInteger)ttl {
    _ttl = ttl;
    
    if (self.isPinging) {
        [self restart];
    }
}

-(NSUInteger)ttl {
    if (!_ttl) {
        return kDefaultTTL;
    }
    else {
        return _ttl;
    }
}

-(void)setPacketSize:(NSUInteger)packetSize {
    _packetSize = packetSize;
    
    if (self.isPinging) {
        [self restart];
    }
}

-(NSUInteger)packetSize {
    if (!_packetSize) {
        return kDefaultPacketSize;
    }
    else {
        return _packetSize;
    }
}

-(NSTimeInterval)pingPeriod {
    if (!_pingPeriod) {
        return (NSTimeInterval)kDefaultPingPeriod;
    }
    else {
        return _pingPeriod;
    }
}

#pragma mark - public API

-(void)start {
    if (!self.isPinging) {
        self.isPinging = YES;
        
        //set up self
        self.nextSequenceNumber = 0;
        self.pendingPings = [[NSMutableDictionary alloc] init];
        self.timeoutTimers = [[NSMutableDictionary alloc] init];
        
        //set up SimplePing
        self.simplePing = [SimplePing simplePingWithHostName:self.host];
        self.simplePing.ttl = self.ttl;
        self.simplePing.delegate = self;
        [self.simplePing start];
    }
    else {
        NSLog(@"GBPing: can't start, already pinging");
    }
}

-(void)stop {
    if (self.isPinging) {
        self.isPinging = NO;
        
        //clean up self
        self.nextSequenceNumber = 0;
        [self.pendingPings removeAllObjects];
        self.pendingPings = nil;
        for (NSNumber *key in self.timeoutTimers) {
            NSTimer *timer = self.timeoutTimers[key];
            [timer invalidate];
        }
        [self.timeoutTimers removeAllObjects];
        self.timeoutTimers = nil;
        
        //destroy pinger
        [self.simplePing stop];
        self.simplePing = nil;
        
        //destroy timer
        [self.pingTimer invalidate];
        self.pingTimer = nil;
    }
    else {
        NSLog(@"GBPing: can't stop, not pinging");
    }
}

-(void)restart {
    if (self.isPinging) {
        [self stop];
        [self start];
    }
    else {
        NSLog(@"GBPing: can't restart, not pinging");
    }
}

#pragma mark - ping tick

-(void)pingTick {
    [self.simplePing sendPingWithData:[self generateDataWithLength:(self.packetSize-8)]];
    
    self.nextSequenceNumber += 1;
}

#pragma mark - util {

-(NSData *)generateDataWithLength:(NSUInteger)length {
    //create a buffer full of 7's of specified length
    char tempBuffer[length];
    memset(tempBuffer, 7, length);
    
    return [[NSData alloc] initWithBytes:tempBuffer length:length];
}

#pragma mark - simple ping delegate

-(void)simplePing:(SimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet {
    //WARNING: this one infers data about the packet, rather than actually reading it, so it could be wrong in the case where someone sends us an ICMP packet which happens to have the same seq number as one of the packets we were expecting.
    NSLog(@"gbping: unexpected packet");

    GBPingSummary *newPingSummary = [[GBPingSummary alloc] init];
    newPingSummary.host = self.host;
    newPingSummary.receiveDate = [NSDate date];
    newPingSummary.sequenceNumber = self.nextSequenceNumber;
    newPingSummary.ttl = self.ttl;
    newPingSummary.packetSize = self.packetSize;
    newPingSummary.status = GBPingStatusFail;
    
    [self.delegate ping:self didReceiveUnexpectedReplyWithSummary:newPingSummary fromHost:self.host];
}

-(void)simplePing:(SimplePing *)pinger didFailToSendPacket:(NSData *)packet error:(NSError *)error {
    NSLog(@"gbping: failed to send packet with error code: %d", error.code);
    [self.delegate ping:self didFailToSendPingToHost:self.host withSequenceNumber:self.nextSequenceNumber];
}

-(void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address {
    self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:self.pingPeriod target:self selector:@selector(pingTick) userInfo:nil repeats:YES];
    [self.pingTimer fire];
}

-(void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error {
    NSLog(@"gbping: failed with error code: %d", error.code);
    
    [self stop];//stop the timers etc.//foo this calls stop on an already stopped simpleping, hope thats ok
    
    [self.delegate ping:self didFailWithError:error];
}

-(void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet {
    //construct ping summary, as much as it can
    GBPingSummary *newPingSummary = [[GBPingSummary alloc] init];
    newPingSummary.host = self.host;
    newPingSummary.sendDate = [NSDate date];
    newPingSummary.sequenceNumber = self.nextSequenceNumber;
    newPingSummary.status = GBPingStatusPending;
    newPingSummary.ttl = self.ttl;
    newPingSummary.packetSize = self.packetSize;
    
    //add it to pending pings
    self.pendingPings[@(self.nextSequenceNumber)] = newPingSummary;
    
    //add a fail timer
    NSTimer *timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:self.timeout repeats:NO withBlock:^{
        newPingSummary.status = GBPingStatusFail;
        [self.delegate ping:self didTimeoutWithSummary:newPingSummary fromHost:self.host];
        
        [self.timeoutTimers removeObjectForKey:@(self.nextSequenceNumber)];
    }];
    
//    //describe it
//    timeoutTimer.gbDescription = [NSString stringWithFormat:@"%d", self.nextSequenceNumber];
    
    //keep a local ref to it
    self.timeoutTimers[@(self.nextSequenceNumber)] = timeoutTimer;
    
    //delegate
    [self.delegate ping:self didSendPingToHost:self.host withSequenceNumber:self.nextSequenceNumber];
}

-(void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet withSequenceNumber:(NSUInteger)seqNo {
    //record receive date
    GBPingSummary *pingSummary = (GBPingSummary *)self.pendingPings[@(seqNo)];
    if (pingSummary) {
        pingSummary.receiveDate = [NSDate date];
        pingSummary.sequenceNumber = seqNo;
        pingSummary.ttl = pinger.ttl;
        pingSummary.status = GBPingStatusSuccess;
        
        //remove it from pending pings
        [self.pendingPings removeObjectForKey:@(seqNo)];
        
        //invalidate the timeouttimer
        NSTimer *timer = self.timeoutTimers[@(seqNo)];
        [timer invalidate];
        [self.timeoutTimers removeObjectForKey:@(seqNo)];
        
        //notify delegate
        [self.delegate ping:self didReceiveReplyWithSummary:pingSummary fromHost:self.host];
    }
}

#pragma mark - memory

-(void)dealloc {
    self.delegate = nil;
    self.host = nil;
    self.simplePing = nil;
    self.pingTimer = nil;
    self.timeoutTimers = nil;
    self.pendingPings = nil;
}

@end
