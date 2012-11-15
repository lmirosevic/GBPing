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

#if TARGET_OS_EMBEDDED || TARGET_IPHONE_SIMULATOR
    #import <CFNetwork/CFNetwork.h>
#else
    #import <CoreServices/CoreServices.h>
#endif

#import "ICMPHeader.h"

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

@property (assign, atomic) int                          socket;
@property (assign, nonatomic) CFHostRef                 hostRef;
//@property (assign, nonatomic) struct addrinfo           *addrPointer;
@property (strong, nonatomic) NSData                    *hostAddress;//foo dealloc this
@property (assign, nonatomic) uint16_t                  identifier;

@property (assign, atomic, readwrite) BOOL              isPinging;
@property (assign, atomic, readwrite) BOOL              isReady;
@property (assign, nonatomic) NSUInteger                nextSequenceNumber;
@property (strong, nonatomic) NSMutableDictionary       *pendingPings;
@property (strong, nonatomic) NSMutableDictionary       *timeoutTimers;

@property (assign, nonatomic) dispatch_queue_t          myQueue;

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

-(void)setupWithBlock:(StartupCallback)callback {
//    @synchronized(self) {//foo maybe not
    
        if (!self.isReady) {

            
            //set up data structs
            self.nextSequenceNumber = 0;
            self.pendingPings = [[NSMutableDictionary alloc] init];
            self.timeoutTimers = [[NSMutableDictionary alloc] init];

            
            
            //foo make sure im not leaking any objects when i error out
            
            
            
            
            
            

            dispatch_async(self.myQueue, ^{
                CFStreamError streamError;
                
                if (!self.host) {
                    l(@"GBPing: set host before attempting to start.");
                    
                    //notify about error and return
                    dispatch_async(dispatch_get_main_queue(), ^{
                        callback(NO, nil);
                    });
                    return;
                }
                
                self.hostRef = CFHostCreateWithName(NULL, (__bridge CFStringRef)self.host);
                
                BOOL success = CFHostStartInfoResolution(self.hostRef, kCFHostAddresses, &streamError);

                if (!success) {
                    //get an error
                    NSDictionary *userInfo;
                    NSError *error;
                    
                    if (streamError.domain == kCFStreamErrorDomainNetDB) {
                        userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInteger:streamError.error], kCFGetAddrInfoFailureKey,
                                    nil
                                    ];
                    }
                    else {
                        userInfo = nil;
                    }
                    error = [NSError errorWithDomain:(NSString *)kCFErrorDomainCFNetwork code:kCFHostErrorUnknown userInfo:userInfo];
                    assert(error != nil);
                    
                    //notify about error and return
                    dispatch_async(dispatch_get_main_queue(), ^{
                        callback(NO, error);
                    });
                    return;
                }
                
                //get the first IPv4 address
                Boolean resolved;
                const struct sockaddr *addrPtr;
                NSArray *addresses = (__bridge NSArray *)CFHostGetAddressing(self.hostRef, &resolved);
                if (resolved && (addresses != nil)) {
                    resolved = false;
                    for (NSData *address in addresses) {
                        const struct sockaddr *anAddrPtr = (const struct sockaddr *)[address bytes];
                        
                        if ([address length] >= sizeof(struct sockaddr) && anAddrPtr->sa_family == AF_INET) {
                            resolved = true;
                            //foo make sure this addrpointer is retained past this scope and that it survives in the send call, and also that i release it when i stop the whole party
                            addrPtr = anAddrPtr;
                            self.hostAddress = address;
                            break;
                        }
                    }
                }

                //stop host resolution
                if (self.hostRef) {
                    CFRelease(self.hostRef);
                    self.hostRef = nil;
                }
                
                //if an error occurred during resolution
                if (!resolved) {
                    //notify about error and return                
                    dispatch_async(dispatch_get_main_queue(), ^{
                        callback(NO, [NSError errorWithDomain:(NSString *)kCFErrorDomainCFNetwork code:kCFHostErrorHostNotFound userInfo:nil]);
                    });
                    return;
                }
                
                //set up socket
                int err = 0;
                switch (addrPtr->sa_family) {
                    case AF_INET: {
                        self.socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
                        if (self.socket < 0) {
                            err = errno;
                        }
                    } break;
                    case AF_INET6: {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            callback(NO, nil);
                        });
                        return;
                    } break;
                    default: {
                        err = EPROTONOSUPPORT;
                    } break;
                }
                
                //couldnt setup socket
                if (err) {
                    //notify about error and close
                    dispatch_async(dispatch_get_main_queue(), ^{
                        callback(NO, [NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil]);
                    });
                    return;
                }
                
                //set ttl on the socket
                if (self.ttl) {
                    setsockopt(self.socket, IPPROTO_IP, IP_TTL, &_ttl, sizeof(NSUInteger));
                }
                
    //                //set up GCD dispatch source
    //                self.dispatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, self.socket, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    //                dispatch_source_set_event_handler(self.dispatchSource, ^{
    //                    [self readData];
    //                });
    //                dispatch_resume(self.dispatchSource);
                
                //we are ready now
                self.isReady = YES;
                
                //notify delegate that we are ready
                if (self.delegate && [self.delegate respondsToSelector:@selector(simplePing:didStartWithAddress:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        callback(YES, nil);
                    });
                }
            });
        }
        else {
            l(@"GBPing: Can't setup, already setup.");
        }
//    }
}


-(void)startPinging {
//    @synchronized(self) {
        if (!self.isPinging) {
            //go into infinite listenloop on a new thread (listenThread)
            NSThread *listenThread = [[NSThread alloc] initWithTarget:self selector:@selector(listenLoop) object:nil];
            listenThread.name = @"listenThread";

            //set up timer that sends packets on a new thread (sendThread)
            NSThread *sendThread = [[NSThread alloc] initWithTarget:self selector:@selector(sendLoop) object:nil];
            sendThread.name = @"sendThread";
            
            //we're pinging now
            self.isPinging = YES;
            [listenThread start];
            [sendThread start];
        }
//    }
}


//foo factor out all the calls to didfailwitherror into a common method that cleans up, stops the pinging, closes the sockte, and sends the delegate notification

-(void)listenLoop {
    @autoreleasepool {
        while (self.isPinging) {
            
            int                     err;
            struct sockaddr_storage addr;
            socklen_t               addrLen;
            ssize_t                 bytesRead;
            void *                  buffer;
            enum { kBufferSize = 65535 };
            
            buffer = malloc(kBufferSize);
            assert(buffer);
            
            //read the data.
            addrLen = sizeof(addr);
            bytesRead = recvfrom(self.socket, buffer, kBufferSize, 0, (struct sockaddr *)&addr, &addrLen);
            err = 0;
            if (bytesRead < 0) {
                err = errno;
            }
            
            //process the data we read.
            if (bytesRead > 0) {
                NSDate *receiveDate = [NSDate date];
                NSMutableData *packet;
                
                packet = [NSMutableData dataWithBytes:buffer length:(NSUInteger) bytesRead];
                assert(packet);
                
                //complete the ping summary
                const struct ICMPHeader *headerPointer = [[self class] icmpInPacket:packet];
                NSUInteger seqNo = (NSUInteger)OSSwapBigToHostInt16(headerPointer->sequenceNumber);
                NSNumber *key = @(seqNo);
                GBPingSummary *pingSummary = (GBPingSummary *)self.pendingPings[key];
                pingSummary.receiveDate = receiveDate;
//                pingSummary.sequenceNumber = seqNo;
//                pingSummary.ttl = self.ttl;
//                pingSummary.payloadSize = self.payloadSize;
                
                //foo make sure all of the above are set when the ping is first sent
                
                
                if ([self isValidPingResponsePacket:packet]) {
                    if (self.delegate && [self.delegate respondsToSelector:@selector(ping:didReceiveReplyWithSummary:)] ) {
                        if (pingSummary) {
                            pingSummary.status = GBPingStatusSuccess;
                            
                            //remove it from pending pings
                            [self.pendingPings removeObjectForKey:key];
                            
                            //invalidate the timeouttimer
                            NSTimer *timer = self.timeoutTimers[key];
                            [timer invalidate];
                            [self.timeoutTimers removeObjectForKey:key];
                            
                            dispatch_async(dispatch_get_main_queue(), ^{//foo maybe use nsthreads for this
                                //notify delegate
                                [self.delegate ping:self didReceiveReplyWithSummary:pingSummary];
                            });
                        }
                    }
                }
                else {
                    if (self.delegate && [self.delegate respondsToSelector:@selector(ping:didReceiveUnexpectedReplyWithSummary:)] ) {
                        if (pingSummary) {
                            pingSummary.status = GBPingStatusFail;

                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.delegate ping:self didReceiveReplyWithSummary:pingSummary];
                            });
                        }
                    }
                }
            }
            else {
                
                //we failed to read the data, so shut everything down.
                if (err == 0) {
                    err = EPIPE;
                }
                
                //foo stop pinging and all of that, close sockets, etc
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate ping:self didFailWithError:[NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil]];
                });
            }
            
            free(buffer);

            
            
        }
    }
    
}

-(void)sendLoop {
    @autoreleasepool {
        while (self.isPinging) {
            [self sendPing];
            sleep(self.pingPeriod);//foo make sure these are seconds
        }
    }
}

-(void)sendPing {
    if (self.isPinging) {
        
        int err;
        NSMutableData *packet;
        ICMPHeader *icmpPtr;
        ssize_t bytesSent;
        
        // Construct the ping packet.
        
        NSData *payload = [self generateDataWithLength:(self.payloadSize)];
//        if (payload == nil) {
//            payload = [[NSString stringWithFormat:@"%28zd bottles of beer on the wall", (ssize_t) 99 - (size_t) (self.nextSequenceNumber % 100) ] dataUsingEncoding:NSASCIIStringEncoding];
//            assert(payload != nil);
//            
//            assert([payload length] == 56);
//        }
        
        packet = [NSMutableData dataWithLength:sizeof(*icmpPtr) + [payload length]];
//        assert(packet != nil);
        
        icmpPtr = [packet mutableBytes];
        icmpPtr->type = kICMPTypeEchoRequest;
        icmpPtr->code = 0;
        icmpPtr->checksum = 0;
        icmpPtr->identifier     = OSSwapHostToBigInt16(self.identifier);
        icmpPtr->sequenceNumber = OSSwapHostToBigInt16(self.nextSequenceNumber);
        memcpy(&icmpPtr[1], [payload bytes], [payload length]);
        
        // The IP checksum returns a 16-bit number that's already in correct byte order
        // (due to wacky 1's complement maths), so we just put it into the packet as a
        // 16-bit unit.
        
        icmpPtr->checksum = in_cksum([packet bytes], [packet length]);
        
        // Send the packet.
        
        if (self.socket == 0) {
            bytesSent = -1;
            err = EBADF;
        }
        else {
            bytesSent = sendto(
                               self.socket,
                               [packet bytes],
                               [packet length],
                               0,
                               (struct sockaddr *) [self.hostAddress bytes],
                               (socklen_t) [self.hostAddress length]
                               );
            err = 0;
            if (bytesSent < 0) {
                err = errno;
            }
        }
        
        // Handle the results of the send.
        NSDate *sendDate = [NSDate date];
        
        //foo make sure these delegate calls are sent on the right thread
        
        
        //construct ping summary, as much as it can
        GBPingSummary *newPingSummary = [[GBPingSummary alloc] init];
        newPingSummary.host = self.host;
        newPingSummary.sendDate = sendDate;
        newPingSummary.sequenceNumber = self.nextSequenceNumber;
        newPingSummary.ttl = self.ttl;
        newPingSummary.payloadSize = self.payloadSize;
        
        
        
        //successfully sent
        if ((bytesSent > 0) && (((NSUInteger) bytesSent) == [packet length])) {
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(ping:didSendPingWithSummary:)]) {
                newPingSummary.status = GBPingStatusPending;
                
                
                //        NSNumber *key = @(self.nextSequenceNumber);
                //
                //        //add it to pending pings
                //        self.pendingPings[key] = newPingSummary;
                //
                //        //add a fail timer
                //        NSTimer *timeoutTimer = [NSTimer timerWithTimeInterval:self.timeout repeats:NO withBlock:^{
                //            newPingSummary.status = GBPingStatusFail;
                //
                //            [self.delegate ping:self didTimeoutWithSummary:newPingSummary];
                //
                //            [self.pendingPings removeObjectForKey:key];
                //
                //            [self.timeoutTimers removeObjectForKey:key];
                //        }];
                //        [[NSRunLoop mainRunLoop] addTimer:timeoutTimer forMode:NSRunLoopCommonModes];
                //        
                //        //keep a local ref to it
                //        self.timeoutTimers[key] = timeoutTimer;
                //        
                //        //delegate
                //        [self.delegate ping:self didSendPingToHost:self.host withSequenceNumber:self.nextSequenceNumber];

                
                
                
                
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate ping:self didSendPingWithSummary:newPingSummary];
                });
            }
        }
        //failed to send
        else {
            NSError *error;
            // Some sort of failure.  Tell the client.
            
            if (err == 0) {
                err = ENOBUFS;          // This is not a hugely descriptor error, alas.
            }
            error = [NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil];
            if (self.delegate && [self.delegate respondsToSelector:@selector(ping:didFailToSendPingWithSummary:)]) {
                newPingSummary.status = GBPingStatusFail;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate ping:self didFailToSendPingWithSummary:newPingSummary];
                });
            }
        }
        
        self.nextSequenceNumber += 1;
        
        
        
        
        
        
        
        
        
        
        


        
        
        
        
        
        
        
        
        
//        NSLog(@"GBPing: failed to send packet with error code: %d", error.code);
//        
//        [self.delegate ping:self didFailToSendPingToHost:self.host withSequenceNumber:self.nextSequenceNumber];
        
    }
}

-(void)stop {
//    @synchronized(self) {
    if (self.isReady) {
        if (self.isPinging) {
            //destroy loop that sends new packets (sendThread)
            
            //foo shud put a log here that says the pinging is asked to be stopped
            self.isPinging = NO;
            //foo shud put a log here, or inside sendloop to make sure it stopped
        }
        
        //destroy listenThread by closing socket (listenThread)
        close(self.socket);
        self.socket = 0;
        
        //clean up data structures
        [self.pendingPings removeAllObjects];
        self.pendingPings = nil;
        for (NSNumber *key in self.timeoutTimers) {
            NSTimer *timer = self.timeoutTimers[key];
            [timer invalidate];
        }
        [self.timeoutTimers removeAllObjects];
        self.timeoutTimers = nil;
    }
    else {
        NSLog(@"GBPing: can't stop, not pinging");
        
    }
    
//    }
}


#pragma mark - Apple SimplePing data processing methods

static uint16_t in_cksum(const void *buffer, size_t bufferLen)
// This is the standard BSD checksum code, modified to use modern types.
{
	size_t              bytesLeft;
    int32_t             sum;
	const uint16_t *    cursor;
	union {
		uint16_t        us;
		uint8_t         uc[2];
	} last;
	uint16_t            answer;
    
	bytesLeft = bufferLen;
	sum = 0;
	cursor = buffer;
    
	/*
	 * Our algorithm is simple, using a 32 bit accumulator (sum), we add
	 * sequential 16 bit words to it, and at the end, fold back all the
	 * carry bits from the top 16 bits into the lower 16 bits.
	 */
	while (bytesLeft > 1) {
		sum += *cursor;
        cursor += 1;
		bytesLeft -= 2;
	}
    
	/* mop up an odd byte, if necessary */
	if (bytesLeft == 1) {
		last.uc[0] = * (const uint8_t *) cursor;
		last.uc[1] = 0;
		sum += last.us;
	}
    
	/* add back carry outs from top 16 bits to low 16 bits */
	sum = (sum >> 16) + (sum & 0xffff);	/* add hi 16 to low 16 */
	sum += (sum >> 16);			/* add carry */
	answer = (uint16_t) ~sum;   /* truncate to 16 bits */
    
	return answer;
}

+ (NSUInteger)icmpHeaderOffsetInPacket:(NSData *)packet
// Returns the offset of the ICMPHeader within an IP packet.
{
    NSUInteger              result;
    const struct IPHeader * ipPtr;
    size_t                  ipHeaderLength;
    
    result = NSNotFound;
    if ([packet length] >= (sizeof(IPHeader) + sizeof(ICMPHeader))) {
        ipPtr = (const IPHeader *) [packet bytes];
        assert((ipPtr->versionAndHeaderLength & 0xF0) == 0x40);     // IPv4
        assert(ipPtr->protocol == 1);                               // ICMP
        ipHeaderLength = (ipPtr->versionAndHeaderLength & 0x0F) * sizeof(uint32_t);
        if ([packet length] >= (ipHeaderLength + sizeof(ICMPHeader))) {
            result = ipHeaderLength;
        }
    }
    return result;
}

+ (const struct ICMPHeader *)icmpInPacket:(NSData *)packet
// See comment in header.
{
    const struct ICMPHeader *   result;
    NSUInteger                  icmpHeaderOffset;
    
    result = nil;
    icmpHeaderOffset = [self icmpHeaderOffsetInPacket:packet];
    if (icmpHeaderOffset != NSNotFound) {
        result = (const struct ICMPHeader *) (((const uint8_t *)[packet bytes]) + icmpHeaderOffset);
    }
    return result;
}

- (BOOL)isValidPingResponsePacket:(NSMutableData *)packet
// Returns true if the packet looks like a valid ping response packet destined
// for us.
{
    BOOL                result;
    NSUInteger          icmpHeaderOffset;
    ICMPHeader *        icmpPtr;
    uint16_t            receivedChecksum;
    uint16_t            calculatedChecksum;
    
    result = NO;
    
    icmpHeaderOffset = [[self class] icmpHeaderOffsetInPacket:packet];
    if (icmpHeaderOffset != NSNotFound) {
        icmpPtr = (struct ICMPHeader *) (((uint8_t *)[packet mutableBytes]) + icmpHeaderOffset);
        
        receivedChecksum   = icmpPtr->checksum;
        icmpPtr->checksum  = 0;
        calculatedChecksum = in_cksum(icmpPtr, [packet length] - icmpHeaderOffset);
        icmpPtr->checksum  = receivedChecksum;
        
        if (receivedChecksum == calculatedChecksum) {
            if ( (icmpPtr->type == kICMPTypeEchoReply) && (icmpPtr->code == 0) ) {
                if ( OSSwapBigToHostInt16(icmpPtr->identifier) == self.identifier ) {
                    if ( OSSwapBigToHostInt16(icmpPtr->sequenceNumber) < self.nextSequenceNumber ) {
                        result = YES;
                    }
                }
            }
        }
    }
    
    return result;
}

#pragma mark - util 

-(NSData *)generateDataWithLength:(NSUInteger)length {
    //create a buffer full of 7's of specified length
    char tempBuffer[length];
    memset(tempBuffer, 7, length);
    
    return [[NSData alloc] initWithBytes:tempBuffer length:length];
}






#pragma mark - simple ping delegate

//-(void)simplePing:(SimplePing *)pinger didFailToSendPacket:(NSData *)packet error:(NSError *)error {
//    NSLog(@"GBPing: failed to send packet with error code: %d", error.code);
//    
//    [self.delegate ping:self didFailToSendPingToHost:self.host withSequenceNumber:self.nextSequenceNumber];
//}

//-(void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error {
//    NSLog(@"GBPing: failed with error code: %d", error.code);
//    
//    [self stop];//stop the timers etc
//    
//    [self.delegate ping:self didFailWithError:error];
//}


#pragma mark - memory

-(id)init {
    if (self = [super init]) {
        self.myQueue = dispatch_queue_create("GBPing queue", 0);
    }
    
    return self;
}

-(void)dealloc {
    self.delegate = nil;
    self.host = nil;
    self.timeoutTimers = nil;
    self.pendingPings = nil;
    
    //clean up dispatch queue
    if (self.myQueue) {
        //foo check that this actually works
        dispatch_release(self.myQueue);
        self.myQueue = nil;
    }
}

@end
