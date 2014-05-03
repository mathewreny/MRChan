MRChan
======

Objective-c implementation of Golang channels.

How to create a channel.

    MRChan *uchannel = [[MRChan alloc] init];           // unbuffered channel.
    MRChan *bchannel = [[MRChan alloc] initWithSize:5]; // buffered channel

Sending to a channel blocks (waits) until there is a value to receive.

    MRChan *channel = [[MRChan alloc] init];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(10);
        [channel send:@2];
    });
    NSNumber *received;
    [channel receive:&received];
    XCTAssert(received.intValue == 2);
    
The select method pseudorandomly tests every `SelectCase` until one is ready.

    MRChan *channel = [[MRChan alloc] init];
    // Begin randomally sending 1s and 0s to the channel.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        SelectCase send0 = [channel caseSend:@0 block:^{ NSLog(@"Sent 0");}];
        SelectCase send1 = [channel caseSend:@1 block:nil];
        while (1)
            [MRChan select:send0, send1, nil];  // need to terminate the list with nil.
    });
    // create 1000 random numbers.
    uint *numbers = calloc(1000, sizeof(uint));
    for (int i = 0; i < 1000; i++)
    {
        NSNumber *rec;
        for (int j = 0; j < 32; j++)
        {
            [channel receive:&rec];
            random[i] = (random[i] << 1) | rec.intValue;
        }
    }
    
Select statements can intermix receive and send cases.

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
    
    
    
    
