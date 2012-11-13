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
    return [self.receiveDate timeIntervalSinceDate:self.sendDate];
}

-(void)dealloc {
    self.host = nil;
    self.sendDate = nil;
    self.receiveDate = nil;
}

@end
