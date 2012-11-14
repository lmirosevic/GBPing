//
//  GBPing.m
//  GBPing
//
//  Created by Luka Mirosevic on 05/11/2012.
//  Copyright (c) 2012 Goonbee. All rights reserved.
//

#define kDefaultPayloadSize 56
#define kDefaultTTL 49
#define kDefaultPingPeriod 1
#define kDefaultTimeout 2

#import "GBPing.h"

#import "GBPingSummary.h"

@interface GBPing ()

@property (nonatomic, strong) SimplePing *simplePing;
@property (assign, atomic, readwrite) BOOL isPinging;
@property (nonatomic, strong) NSTimer *pingTimer;
@property (assign, atomic) NSUInteger nextSequenceNumber;
@property (nonatomic, strong) NSMutableDictionary *pendingPings;
@property (nonatomic, strong) NSMutableDictionary *timeoutTimers;

@end

@implementation GBPing

@synthesize payloadSize = _payloadSize;
@synthesize ttl = _ttl;
@synthesize timeout = _timeout;
@synthesize pingPeriod = _pingPeriod;

#pragma mark - custom acc

-(void)setTimeout:(NSTimeInterval)timeout {
    if (self.isPinging) {
        NSLog(@"GBPing: can't set timeout while pinger is running.");
    }
    else {
        _timeout = timeout;
    }
}

-(NSTimeInterval)timeout {
    if (!_timeout) {
        return kDefaultTimeout;
    }
    else {
        return _timeout;
    }
}

-(void)setTtl:(NSUInteger)ttl {
    if (self.isPinging) {
        NSLog(@"GBPing: can't set ttl while pinger is running.");
    }
    else {
        _ttl = ttl;
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

-(void)setPayloadSize:(NSUInteger)payloadSize {
    if (self.isPinging) {
        NSLog(@"GBPing: can't set payload size while pinger is running.");
    }
    else {
        _payloadSize = payloadSize;
    }
}

-(NSUInteger)payloadSize {
    if (!_payloadSize) {
        return kDefaultPayloadSize;
    }
    else {
        return _payloadSize;
    }
}

-(void)setPingPeriod:(NSTimeInterval)pingPeriod {
    if (self.isPinging) {
        NSLog(@"GBPing: can't set pingPeriod while pinger is running.");
    }
    else {
        _pingPeriod = pingPeriod;
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

-(void)setup {
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
        NSLog(@"GBPing: can't setup, already pinging");
    }
}

-(void)start {
    if (self.isPinging) {
        self.pingTimer = [NSTimer timerWithTimeInterval:self.pingPeriod target:self selector:@selector(pingTick) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:self.pingTimer forMode:NSRunLoopCommonModes];
        [self.pingTimer fire];
    }
    else {
        NSLog(@"GBPing: can't start, not pinging. Call setup first");
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
        l(@"destroy SimplePing");
        self.simplePing = nil;
        
        //destroy timer
        [self.pingTimer invalidate];
        self.pingTimer = nil;
    }
    else {
        NSLog(@"GBPing: can't stop, not pinging");
    }
}

#pragma mark - ping tick

-(void)pingTick {
//    NSLog(@"make sure this is main queue12: %s", dispatch_queue_get_label(dispatch_get_current_queue()));
    
    //send a ping on a background thread
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self.simplePing sendPingWithData:[self generateDataWithLength:(self.payloadSize)]];
        self.nextSequenceNumber += 1;
//    });
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
//    NSLog(@"GBPing: unexpected packet");
    
//    NSLog(@"make sure this is bg queue1: %s", dispatch_queue_get_label(dispatch_get_current_queue()));

    GBPingSummary *newPingSummary = [[GBPingSummary alloc] init];
    newPingSummary.host = self.host;
    newPingSummary.receiveDate = [NSDate date];
    newPingSummary.sequenceNumber = self.nextSequenceNumber;
    newPingSummary.ttl = self.ttl;
    newPingSummary.payloadSize = self.payloadSize;
    newPingSummary.status = GBPingStatusFail;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        //NOTE this is back on the main queue
        [self.delegate ping:self didReceiveUnexpectedReplyWithSummary:newPingSummary fromHost:self.host];
    });
}

-(void)simplePing:(SimplePing *)pinger didFailToSendPacket:(NSData *)packet error:(NSError *)error {
    
//    NSLog(@"make sure this is main queue1: %s", dispatch_queue_get_label(dispatch_get_current_queue()));
    NSLog(@"GBPing: failed to send packet with error code: %d", error.code);
    
    [self.delegate ping:self didFailToSendPingToHost:self.host withSequenceNumber:self.nextSequenceNumber];
}

-(void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address {
    
//    NSLog(@"make sure this is main queue2: %s", dispatch_queue_get_label(dispatch_get_current_queue()));
//    NSLog(@"GBPing: successfully started");
    
    
    [self.delegate pingDidSuccessfullySetup:self];
}

-(void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error {
    
//    NSLog(@"make sure this is main queue3: %s", dispatch_queue_get_label(dispatch_get_current_queue()));
    NSLog(@"GBPing: failed with error code: %d", error.code);
    
    [self stop];//stop the timers etc.//foo this calls stop on an already stopped simpleping, hope thats ok
    
    [self.delegate ping:self didFailWithError:error];
}

-(void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet {
    
//    NSLog(@"make sure this is main queue4: %s", dispatch_queue_get_label(dispatch_get_current_queue()));
    
    //construct ping summary, as much as it can
    GBPingSummary *newPingSummary = [[GBPingSummary alloc] init];
    newPingSummary.host = self.host;
    newPingSummary.sendDate = [NSDate date];
    newPingSummary.sequenceNumber = self.nextSequenceNumber;
    newPingSummary.status = GBPingStatusPending;
    newPingSummary.ttl = self.ttl;
    newPingSummary.payloadSize = self.payloadSize;
    
    //add it to pending pings
    self.pendingPings[@(self.nextSequenceNumber)] = newPingSummary;
    
    //add a fail timer
    NSTimer *timeoutTimer = [NSTimer timerWithTimeInterval:self.timeout repeats:NO withBlock:^{
        newPingSummary.status = GBPingStatusFail;
        
        [self.delegate ping:self didTimeoutWithSummary:newPingSummary fromHost:self.host];
        
        [self.timeoutTimers removeObjectForKey:@(self.nextSequenceNumber)];
    }];
    [[NSRunLoop mainRunLoop] addTimer:timeoutTimer forMode:NSRunLoopCommonModes];
    
    //keep a local ref to it
    self.timeoutTimers[@(self.nextSequenceNumber)] = timeoutTimer;
    
    //delegate
    [self.delegate ping:self didSendPingToHost:self.host withSequenceNumber:self.nextSequenceNumber];
}

-(void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet withSequenceNumber:(NSUInteger)seqNo {
    
//    NSLog(@"make sure this is bg queue3: %s", dispatch_queue_get_label(dispatch_get_current_queue()));
    
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
        dispatch_async(dispatch_get_main_queue(), ^{
            //NOTE back on main queue
            [self.delegate ping:self didReceiveReplyWithSummary:pingSummary fromHost:self.host];
        });
    }
}

#pragma mark - memory

//-(id)init {
//    if (self = [super init]) {
//        
//    }
//    
//    return self;
//}

-(void)dealloc {
    self.delegate = nil;
    self.host = nil;
    self.simplePing = nil;
    self.pingTimer = nil;
    self.timeoutTimers = nil;
    self.pendingPings = nil;
}

@end
