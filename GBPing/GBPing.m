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

#import "GBPing.h"

#import "GBPingSummary.h"

@interface GBPing ()

@property (nonatomic, strong) SimplePing *simplePing;
@property (nonatomic, readwrite) BOOL isPinging;
@property (nonatomic, strong) NSTimer *pingTimer;
@property (nonatomic) NSUInteger nextSequenceNumber;
@property (nonatomic, strong) NSMutableDictionary *pendingPings;

@end

@implementation GBPing

@synthesize packetSize = _packetSize;
@synthesize ttl = _ttl;

#pragma mark - custom acc

//-(NSMutableDictionary *)pendingPings {
//    if (!_pendingPings) {
//        _pendingPings = [[NSMutableDictionary alloc] init];
//    }
//    
//    return _pendingPings;
//}

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

-(void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address { 
    //set up ping timer
    self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:self.pingPeriod target:self selector:@selector(pingTick) userInfo:nil repeats:YES];
    [self.pingTimer fire];
}

-(void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error {
    NSLog(@"failed with error: %d", error.code);
}

-(void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet {
    //construct ping summary, as much as it can
    GBPingSummary *newPingSummary = [[GBPingSummary alloc] init];
    newPingSummary.host = self.host;
    newPingSummary.sendDate = [NSDate date];
    newPingSummary.sequenceNumber = self.nextSequenceNumber;
    
    //add it to pending pings
    self.pendingPings[@(self.nextSequenceNumber)] = newPingSummary;
    
    //delegate
    [self.delegate ping:self didSendPingToHost:self.host withSequenceNumber:self.nextSequenceNumber];
}

-(void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet withSequenceNumber:(NSUInteger)seqNo {
    //record receive date
    GBPingSummary *pingSummary = (GBPingSummary *)self.pendingPings[@(seqNo)];
    if (pingSummary) {
        pingSummary.receiveDate = [NSDate date];
        
        //set seq no
        pingSummary.sequenceNumber = seqNo;
        
        //set ttl
        pingSummary.ttl = pinger.ttl;
        
        //remove it from pending pings
        [self.pendingPings removeObjectForKey:@(seqNo)];
        
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
}

@end
