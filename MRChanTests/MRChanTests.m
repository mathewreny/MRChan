/*
 The MIT License (MIT)
 
 Copyright (c) 2014 Mathew Reny
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

#import <XCTest/XCTest.h>
#import "MRChan.h"

@interface MRChanTests : XCTestCase

@end

@implementation MRChanTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

/**
 Create |sample_size| ammount of 32 bit random numbers using a select statement. Make sure none of the numbers are equal.
 */
- (void)testSelectStatement32BitPseudorandomness1
{
    MRChan *chan = [MRChan make];
    const uint sample_size = 1000;
    const uint max_threads = 10;
    __block BOOL passed = true;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while(1)
        {
            // Should randomly send 1 and 0 to the channel due to the properties of a channel.
            [MRChan sel:@[[chan selSend:@1 block:nil], [chan selSend:@0 block:nil]]];
        }
    });
    
    NSNumber *rec;
    uint32 *random = calloc(sample_size, sizeof(uint32));
    
    dispatch_semaphore_t limiter = dispatch_semaphore_create(max_threads);
    dispatch_semaphore_t started = dispatch_semaphore_create(0);
    
    
    for (int i = 0; i < sample_size; i++)
    {
        for (int j = 0; j<32; j++)
        {
            [chan receive:&rec];
            
            random[i] |= rec.unsignedIntValue << j;
        }
        dispatch_semaphore_wait(limiter, DISPATCH_TIME_FOREVER);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            uint32 vali = random[i];
            dispatch_semaphore_signal(started);
            NSLog(@"Randomly Generated Number: %d", vali);
            for (int j = 0; j<i; j++)
            {
                if (random[j] == vali)
                {
                    passed = false;
                }
            }
            dispatch_semaphore_signal(limiter);
        });
        dispatch_semaphore_wait(started, DISPATCH_TIME_FOREVER);
    }
    free(random);
    XCTAssert(passed);
}

- (void)testSelectStatement2
{
    MRChan *ch1 = [MRChan make];
    MRChan *timeout = [MRChan make];
    __block BOOL ran = false;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(2);
        [timeout send:@1];
    });
    
    [MRChan
     sel:@[[ch1 selReceive:^(id b_object) {
                XCTFail(@"This shouldn't run");
            }],
           [ch1 selSend:@0 block:^{
                XCTFail(@"This shouldn't run");
            }],
           [timeout selReceive:^(NSNumber *timedout) {
                ran = [timedout boolValue];
            }],
           ]];
    
    XCTAssert(ran);
}

- (void)testSelectStatement1
{
    MRChan *ch1 = [MRChan make:1];
    
    
    NSNumber *__block total;
    for (int i = 0; i < 6; i++)
    {
        [MRChan
         sel:@[[ch1 selReceive:^(NSNumber *obj){
                    total = [NSNumber numberWithInt:obj.intValue+total.intValue];
                    NSLog(@"Got %d", obj.intValue);
                }],
               [ch1 selSend:@1 block:^{
                    NSLog(@"Sent 1");
                }]
               ]];
    }
    
    XCTAssert(total.intValue == 3, @"The total was %d", total.intValue);
}

- (void)testChannelSendAsync
{
    MRChan *ch = [MRChan make];
    NSString *received;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [ch send:@"Test Channel Send Async"];
    });
    
    [ch receive:&received];
    
    XCTAssert([received isEqualToString:@"Test Channel Send Async"], @"The test failed");
}

- (void)testChannelReceiveAsync
{
    MRChan *ch = [MRChan make];
    __block NSString *received;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [ch receive:&received];
    });
    
    [ch send:@"Test Channel Receive Async"];
    NSLog(@"RECEIVED %@", received);
    XCTAssert([received isEqualToString:@"Test Channel Receive Async"], @"The test failed");
}

- (void)testBuffChan
{
    MRChan *bfch = [MRChan make:5];
    
    NSString *hello, *world, *this, *is, *mat;
    
    [bfch send:@"Hello"];
    [bfch send:@"World"];
    [bfch send:@"This"];
    [bfch send:@"Is"];
    [bfch send:@"Mat"];
    
    [bfch receive:&hello]; NSLog(@"%@", hello);
    [bfch receive:&world];
    [bfch receive:&this];
    [bfch receive:&is]; NSLog(@"%@", is);
    [bfch receive:&mat];
    
    XCTAssert([hello isEqualToString:@"Hello"]);
    XCTAssert([world isEqualToString:@"World"]);
    XCTAssert([this isEqualToString:@"This"]);
    XCTAssert([is isEqualToString:@"Is"]);
    XCTAssert([mat isEqualToString:@"Mat"]);
    
    NSString *over, *data;
    
    [bfch send:@"Overwriting"];
    [bfch send:@"Data"];
    
    [bfch receive:&over]; NSLog(@"%@", over);
    [bfch receive:&data]; NSLog(@"%@", data);
    
    XCTAssert([over isEqualToString:@"Overwriting"]);
    XCTAssert([data isEqualToString:@"Data"]);
    
}

- (void)testTooManySends
{
    MRChan *bfch = [MRChan make:5];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [bfch send:@"Hello"];
        [bfch send:@"World"];
        [bfch send:@"This"];
        [bfch send:@"Is"];
        [bfch send:@"Mat"];
        [bfch send:@"Overwriting"];
        [bfch send:@"Data"];
    });
    
    NSString *hello, *world, *this, *is, *mat;
    NSString *over, *data;
    
    [bfch receive:&hello]; NSLog(@"%@", hello);
    XCTAssert([hello isEqualToString:@"Hello"]);
    [bfch receive:&world]; NSLog(@"%@", world);
    XCTAssert([world isEqualToString:@"World"]);
    [bfch receive:&this]; NSLog(@"%@", this);
    XCTAssert([this isEqualToString:@"This"]);
    [bfch receive:&is]; NSLog(@"%@", is);
    XCTAssert([is isEqualToString:@"Is"]);
    [bfch receive:&mat]; NSLog(@"%@", mat);
    XCTAssert([mat isEqualToString:@"Mat"]);
    [bfch receive:&over]; NSLog(@"%@", over);
    XCTAssert([over isEqualToString:@"Overwriting"]);
    [bfch receive:&data]; NSLog(@"%@", data);
    XCTAssert([data isEqualToString:@"Data"]);
}

- (void)testUnbufferedChannels
{
    MRChan *ch = [MRChan make];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i<10000; i++)
        {
            [ch send:@"hello thar"];
        }
    });
    
    NSString *rec;
    for (int i = 0; i<10000; i++)
    {
        [ch receive:&rec];
        XCTAssert([rec isEqualToString:@"hello thar"]);
    }
    rec = @"Breakpoint";
}

- (void)testChannelBuffOneTheNumberSize
{
    MRChan *ch = [MRChan make:1];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i<100000; i++)
        {
            NSString *str = @"hello";
            [ch send:str];
        }
    });
    
    for (int j = 0; j<100000; j++)
    {
        NSString *rec;
        [ch receive:&rec];
        XCTAssert([rec isEqualToString:@"hello"]);
    }
}

- (void)pseudoSelectStatement1:(MRChan *)ch1 ch2:(MRChan *)ch2 ch3:(MRChan *)ch3
{
    NSNumber *rec, *__block total;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [ch1 send:@1];
    });
    
    BOOL ran;
    
    for (int i = 0; i<3; i++) // select.
    {
        usleep(500);
        
        if ([ch1 tryReceive:&rec])
        {
            NSLog(@"GOT %@", rec);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [ch2 send:[NSNumber numberWithInt:([rec intValue]+1)]];
            });
        }
        else if ([ch2 tryReceive:&rec])
        {
            NSLog(@"GOT %@", rec);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [ch3 send:[NSNumber numberWithInt:([rec intValue]+1)]];
            });
        }
        else if ([ch3 tryReceive:&total])
        {
            ran = TRUE;
            XCTAssert((total.intValue == 3));
        }
        else
        {
            XCTFail(@"Test failed");
        }
    }
    
    if (!ran)
    {
        XCTFail(@"Failed to get total");
    }
}

- (void)testPseudoSelectStatement1
{
    [self pseudoSelectStatement1:[MRChan make] ch2:[MRChan make] ch3:[MRChan make]];
    [self pseudoSelectStatement1:[MRChan make:1] ch2:[MRChan make:1] ch3:[MRChan make:1]];
}

/**************************************************************************************************
 Inspired by talks.golang.org/2012/concurrency.slide#39
 */
- (void)testDaisyChain
{
    const int p = 4;
    int n = pow(10,p);
    
    MRChan *left = [MRChan make];
    MRChan *right;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [left send:@1];
    });
    
    dispatch_semaphore_t sem_protect = dispatch_semaphore_create(1);
    for (int i = 0; i<n; i++)
    {
        dispatch_semaphore_wait(sem_protect, DISPATCH_TIME_FOREVER);
        NSNumber *rec;
        [left receive:&rec];
        if ((i % (n/10)) == 0)
        {
            NSLog(@"i = %d Received %d", i, rec.intValue);
        }
        right = nil;
        right = [MRChan make];
        left = right;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSNumber *sum = [NSNumber numberWithInteger:([rec intValue] + 1)];
            dispatch_semaphore_signal(sem_protect);
            [right send:sum];
        });
    }
    
    NSNumber *total;
    [left receive:&total];
    NSLog(@"Total was %@", total);
    XCTAssert((total.intValue == n+1), @"Incorrect total %d", total.intValue);
}
//*************************************************************************************************


- (void)testChannelAsyncCalls
{
    MRChan *ch = [MRChan make:2];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [ch send:@"One"];
        [ch send:@"Two"];
        [ch send:@"Three"];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [ch send:@"Four"];
        [ch send:@"Five"];
        [ch send:@"Six"];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [ch send:@"Seven"];
        [ch send:@"Eight"];
        [ch send:@"Nine"];
    });
    
    NSString *rec;
    for (int i = 0; i<9; i++)
    {
        [ch receive:&rec];
        NSLog(@"Received %@", rec);
    }
    rec = nil;
}




@end
