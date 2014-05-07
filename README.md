MRChan
======

Objective-c implementation of Golang channels.

#### If you know Objective-C, read MRChan.h instead of the examples. It's well documented and easy to follow!

How to create a channel.

    MRChan *channel  = [[MRChan alloc] init];           // unbuffered channel.
    MRChan *bchannel = [[MRChan alloc] initWithSize:5]; // buffered channel

Sending/receiving to/from a channel blocks (waits) until the action can occur.

    NSNumber *rec;
    [bchannel send:@1];      // Buffered channels don't wait to send unless full.
    [bchannel receive:&rec]; //    ""       ""      ""   ""  "" receive ""  empty
    XCTAssert(rec.intValue == 1);
    // Unbuffered channels must send/receive through different coroutines.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(10); // emphasize the ease of using channels
        [channel send:@2];
    });
    [channel receive:&rec];
    XCTAssert(received.intValue == 2);
    
The select method randomly tests every `SelectCase` until one is ready.

Example: Random number generator. 

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        SelectCase send0 = [channel caseSend:@0 block:^{ NSLog(@"Sent 0");}];
        SelectCase send1 = [channel caseSend:@1 block:nil];
        while (1) // Begin randomally sending 1s and 0s to the channel.
            [MRChan select:send0, send1, nil];  // need to terminate the list with nil.
    });
    // create 1000 random numbers.
    uint *numbers = calloc(10000, sizeof(uint));
    for (int i = 0; i < 10000; i++)
    {
        for (int j = 0; j < 32; j++)
        {
            [channel receive:&rec];
            numbers[i] = (numbers[i] << 1) | rec.intValue;
        }
    }
    
Select statements can intermix receive and send cases. 

Example: Quit channel test.

    __block BOOL quit = false;
    MRChan *chan = [[MRChan alloc] initWithSize:3]; // Buffered channel of size 3.
    MRChan *quitChan = [[MRChan alloc] init];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(10);
        [quitChan send:@1];
    });
    SelectCase receiveStuff = [chan caseReceive:^(NSString *str){ NSLog(@"Received string %@", str);}];
    SelectCase sendStuff = [chan caseSend:@"Hello" block:nil];
    SelectCase quitCase = [quitChan caseReceive:^(NSNumber *q){ quit = [q boolValue];}];
    while(!quit) 
    {
        [MRChan select:receiveStuff, sendStuff, quitCase, nil];
    }
    
    
    
    
