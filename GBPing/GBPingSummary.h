//
//  GBPingSummary.h
//  GBPing
//
//  Created by Luka Mirosevic on 05/11/2012.
//  Copyright (c) 2012 Goonbee. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GBPingSummary : NSObject

@property (assign, nonatomic) NSUInteger        sequenceNumber;
@property (assign, nonatomic) NSUInteger        packetSize;
@property (assign, nonatomic) NSUInteger        ttl;
@property (strong, nonatomic) NSString          *host;
@property (strong, nonatomic) NSDate            *sendDate;
@property (strong, nonatomic) NSDate            *receiveDate;
@property (assign, nonatomic) NSTimeInterval    rtt;

@end
