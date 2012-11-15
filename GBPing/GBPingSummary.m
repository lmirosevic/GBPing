//
//  GBPingSummary.m
//  GBPing
//
//  Created by Luka Mirosevic on 05/11/2012.
//  Copyright (c) 2012 Goonbee. All rights reserved.
//

#import "GBPingSummary.h"

@implementation GBPingSummary

-(NSTimeInterval)rtt {
    if (self.sendDate) {
        return [self.receiveDate timeIntervalSinceDate:self.sendDate];
    }
    else {
        return 0;
    }
}

-(id)init {
    if (self = [super init]) {
        self.status = GBPingStatusPending;
    }
    
    return self;
}

-(void)dealloc {
    self.host = nil;
    self.sendDate = nil;
    self.receiveDate = nil;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"host: %@, seq: %d, status: %d, ttl: %d, payloadSize: %d, sendDate: %@, receiveDate: %@, rtt: %f", self.host, self.sequenceNumber, self.status, self.ttl, self.payloadSize, self.sendDate, self.receiveDate, self.rtt];
}

@end
