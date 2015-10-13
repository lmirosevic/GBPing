# GBPing ![Version](https://img.shields.io/cocoapods/v/GBPing.svg?style=flat)&nbsp;![License](https://img.shields.io/badge/license-Apache_2-green.svg?style=flat)

Highly accurate ICMP Ping controller for iOS (not based on Apple Sample Code, see "Details" section)

Details
------------

This code is a low level ping library that gives extremely accurate round-trip timing results without being impacted by UI and other processing on the main thread. This is not the case with most other ping libraries such as the typical Apple SimplePing which are built as a single threaded class interleaved within the main thread of execution, causing them to suffer from all kinds of indeterministic errors. This library is a multi-threaded class built on top of BSD sockets and GCD, delivering the best possible timing accuracy regardless of system resource state or device performance.

Usage
------------

First import header

```objective-c
#import <GBPing/GBPing.h>
```

Basic usage:

```objective-c
self.ping = [[GBPing alloc] init];
self.ping.host = @"google.com";
self.ping.delegate = self;
self.ping.timeout = 1.0;
self.ping.pingPeriod = 0.9;

[self.ping setupWithBlock:^(BOOL success, NSError *error) { //necessary to resolve hostname
    if (success) {
        //start pinging
        [self.ping startPinging];
        
        //stop it after 5 seconds
        [NSTimer scheduledTimerWithTimeInterval:5 repeats:NO withBlock:^{
            NSLog(@"stop it");
            [self.ping stop];
            self.ping = nil;
        }];
    }
    else {
        NSLog(@"failed to start");
    }
}];
```

Implement optional delegate methods:

```objective-c
-(void)ping:(GBPing *)pinger didReceiveReplyWithSummary:(GBPingSummary *)summary {
    NSLog(@"REPLY>  %@", summary);
}

-(void)ping:(GBPing *)pinger didReceiveUnexpectedReplyWithSummary:(GBPingSummary *)summary {
    NSLog(@"BREPLY> %@", summary);
}

-(void)ping:(GBPing *)pinger didSendPingWithSummary:(GBPingSummary *)summary {
    NSLog(@"SENT>   %@", summary);
}

-(void)ping:(GBPing *)pinger didTimeoutWithSummary:(GBPingSummary *)summary {
    NSLog(@"TIMOUT> %@", summary);
}

-(void)ping:(GBPing *)pinger didFailWithError:(NSError *)error {
    NSLog(@"FAIL>   %@", error);
}

-(void)ping:(GBPing *)pinger didFailToSendPingWithSummary:(GBPingSummary *)summary error:(NSError *)error {
    NSLog(@"FSENT>  %@, %@", summary, error);
}
```

Demo project
------------

See: [github.com/lmirosevic/GBPingDemo](https://github.com/lmirosevic/GBPingDemo)

Features
------------

GBPing provides the following info (inside a GBPingSummaryObject exposed as properties):

* NSUInteger        sequenceNumber;
* NSUInteger        payloadSize;
* NSUInteger        ttl;
* NSString          *host;
* NSDate            *sendDate;
* NSDate            *receiveDate;
* NSTimeInterval    rtt;
* GBPingStatus      status;

Dependencies
------------

None

Copyright & License
------------

Copyright 2015 Luka Mirosevic

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this work except in compliance with the License. You may obtain a copy of the License in the LICENSE file, or at:

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

