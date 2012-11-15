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

#include <sys/socket.h>
#include <netinet/in.h>

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <arpa/inet.h>
#include <netdb.h>

@interface GBPing ()

//@property (nonatomic, strong) SimplePing *simplePing;
@property (assign, atomic) int                          socket;
@property (assign, atomic, readwrite) BOOL              isPinging;
@property (nonatomic, strong) NSTimer                   *pingTimer;
@property (assign, nonatomic) NSUInteger                nextSequenceNumber;
@property (nonatomic, strong) NSMutableDictionary       *pendingPings;
@property (nonatomic, strong) NSMutableDictionary       *timeoutTimers;

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

-(void)startWithCallback:(StartupCallback)callback {
//    @synchronized(self) {//foo maybe not
    
    if (!self.isPinging) {
        //resolve host
        struct addrinfo hints, *servinfo, *p;
        int rv;
        
        memset(&hints, 0, sizeof hints);
        hints.ai_family = AF_UNSPEC;
        hints.ai_socktype = SOCK_DGRAM;
        
        if ((rv = getaddrinfo([self.host UTF8String], BeaconPort, &hints, &servinfo)) != 0) {
            fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rv));
        }
        
        // loop through all the results and make a socket
        for(p = servinfo; p != NULL; p = p->ai_next) {
            if ((self.socket = socket(p->ai_family, p->ai_socktype, p->ai_protocol)) == -1) {
                perror("talker: socket");
                continue;
            }
            
            break;
        }
        
        if (p == NULL) {
            fprintf(stderr, "talker: failed to bind socket\n");
        }
        
        int yes = 1;
        //foo might need broadcast here
        if (setsockopt(self.socket, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes)) == -1) {
            perror("setcolopt so_nosignpipe");
        }
        
        // this call is what allows broadcast packets to be sent:
        if (setsockopt(self.socket, SOL_SOCKET, SO_BROADCAST, &yes, sizeof(yes)) == -1) {
            perror("setsockopt (SO_BROADCAST)");
        }
        
        self.connected = YES;
        self.keepPinging = YES;
        
        //start emiting
        while (self.keepPinging) {
            [self sendHello];
            sleep(TickInterval);
        }

        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        Boolean             success;
//        CFHostClientContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
//        CFStreamError       streamError;
        
        if (!self.host) {
            l(@"GBPing: set host before attempting to start.");
            return;
        }
        
        self->_host = CFHostCreateWithName(NULL, (__bridge CFStringRef) self.hostName);
        assert(self->_host != NULL);
        
        CFHostSetClient(self->_host, HostResolveCallback, &context);
        
        CFHostScheduleWithRunLoop(self->_host, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        
        //        NSLog(@">CFHostStartInfoResolution");
        success = CFHostStartInfoResolution(self->_host, kCFHostAddresses, &streamError);
        //        NSLog(@"<CFHostStartInfoResolution");
        if ( ! success ) {
            [self didFailWithHostStreamError:streamError];
        }
        
        
        //set up socket
        
        //call callback with result
        
        //go into infinite listenloop on a new thread (listenThread)
        
        //set up timer that sends packets on a new thread (sendThread)
    }
//    }
}

-(void)stop {
//    @synchronized(self) {
    if (self.isPinging) {
    
    
    
        //detroy timer that sends new packets (sendThread)
        
        //destroy listenThread by closing socket (listenThread)
    
    
    
    }
    
//    }
}

#pragma mark - convenience

//maybe add a method for setting up and destroying the timer
































































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
    [self.simplePing sendPingWithData:[self generateDataWithLength:(self.payloadSize)]];
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

-(void)simplePing:(SimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet atDate:(NSDate *)date {
    //WARNING: this one infers data about the packet, rather than actually reading it, so it could be wrong in the case where someone sends us an ICMP packet which happens to have the same seq number as one of the packets we were expecting.
//    NSLog(@"GBPing: unexpected packet");
    GBPingSummary *newPingSummary = [[GBPingSummary alloc] init];
    newPingSummary.host = self.host;
    newPingSummary.receiveDate = date;
    newPingSummary.sequenceNumber = self.nextSequenceNumber;
    newPingSummary.ttl = self.ttl;
    newPingSummary.payloadSize = self.payloadSize;
    newPingSummary.status = GBPingStatusFail;
    
    [self.delegate ping:self didReceiveUnexpectedReplyWithSummary:newPingSummary];
}

-(void)simplePing:(SimplePing *)pinger didFailToSendPacket:(NSData *)packet error:(NSError *)error {
    NSLog(@"GBPing: failed to send packet with error code: %d", error.code);
    
    [self.delegate ping:self didFailToSendPingToHost:self.host withSequenceNumber:self.nextSequenceNumber];
}

-(void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address {
//    NSLog(@"GBPing: successfully started");
    
    [self.delegate pingDidSuccessfullySetup:self];
}

-(void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error {
    NSLog(@"GBPing: failed with error code: %d", error.code);
    
    [self stop];//stop the timers etc
    
    [self.delegate ping:self didFailWithError:error];
}

-(void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet atDate:(NSDate *)date {
    //construct ping summary, as much as it can
    GBPingSummary *newPingSummary = [[GBPingSummary alloc] init];
    newPingSummary.host = self.host;
    newPingSummary.sendDate = date;
    newPingSummary.sequenceNumber = self.nextSequenceNumber;
    newPingSummary.status = GBPingStatusPending;
    newPingSummary.ttl = self.ttl;
    newPingSummary.payloadSize = self.payloadSize;
    
    NSNumber *key = @(self.nextSequenceNumber);
    
    //add it to pending pings
    self.pendingPings[key] = newPingSummary;
    
    //add a fail timer
    NSTimer *timeoutTimer = [NSTimer timerWithTimeInterval:self.timeout repeats:NO withBlock:^{
        newPingSummary.status = GBPingStatusFail;
        
        [self.delegate ping:self didTimeoutWithSummary:newPingSummary];
        
        [self.pendingPings removeObjectForKey:key];
        
        [self.timeoutTimers removeObjectForKey:key];
    }];
    [[NSRunLoop mainRunLoop] addTimer:timeoutTimer forMode:NSRunLoopCommonModes];
    
    //keep a local ref to it
    self.timeoutTimers[key] = timeoutTimer;
    
    //delegate
    [self.delegate ping:self didSendPingToHost:self.host withSequenceNumber:self.nextSequenceNumber];
}

-(void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet withSequenceNumber:(NSUInteger)seqNo atDate:(NSDate *)date {
    //record receive date
    GBPingSummary *pingSummary = (GBPingSummary *)self.pendingPings[@(seqNo)];
    if (pingSummary) {
        pingSummary.receiveDate = date;
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
        [self.delegate ping:self didReceiveReplyWithSummary:pingSummary];
    }
}

#pragma mark - memory

//-(id)init {
//    if (self = [super init]) {
//    }
//    
//    return self;
//}

-(void)dealloc {
    self.delegate = nil;
    self.host = nil;
    self.pingTimer = nil;
    self.timeoutTimers = nil;
    self.pendingPings = nil;
}

@end
