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

#import "MRChan.h"

#define sem_wait(sem)   dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER)
#define try_wait(sem)   dispatch_semaphore_wait(sem, DISPATCH_TIME_NOW)
#define sem_signal(sem) dispatch_semaphore_signal(sem)

@implementation MRChan
{
    id __strong *_objects; // The ring buffer in buffered channel.
    
#define _buffered (_ints[0] != 0)
#define _buff_sz _ints[0]
#define _pos _ints[1]
#define _next _ints[2]
    int *_ints; // Allows for smallest footprint since unbuffered chans do not use _pos or _next.
#define BUFFERED_INTS_ARRAY_SIZE 3
#define UNBUFFERED_INTS_ARRAY_SIZE 1
    
#define _sem_full  _sem_a
#define _sem_empty _sem_b
#define _sem_sent     _sem_a
#define _sem_received _sem_b
    dispatch_semaphore_t _sem_a;
    dispatch_semaphore_t _sem_b;
    dispatch_semaphore_t _sem_protected_send;
    dispatch_semaphore_t _sem_protected_receive;
}

- (void)dealloc
{
    free(_objects);
    free(_ints);
}

- (instancetype)initWithSize:(NSUInteger)size
{
    self = [super init];
    if (self) {
        if (size > 0)
        {
            // Make a buffered channel.
            _ints = calloc(BUFFERED_INTS_ARRAY_SIZE, sizeof(int));
            _buff_sz = (int)size;
            _objects = (__strong id *)calloc(_buff_sz, sizeof(id));
            _sem_full = dispatch_semaphore_create((long)_buff_sz);
            _sem_empty = dispatch_semaphore_create(0);
        }
        else
        {
            // Make an unbuffered channel.
            _ints = calloc(UNBUFFERED_INTS_ARRAY_SIZE, sizeof(int));
            _objects = (__strong id *)calloc(1, sizeof(id));
            _sem_sent = dispatch_semaphore_create(0);
            _sem_received = dispatch_semaphore_create(0);
        }
        
        _sem_protected_send = dispatch_semaphore_create(1);
        _sem_protected_receive = dispatch_semaphore_create(1);
    }
    return self;
}

/**
 Unbuffered channel.
 */
+ (MRChan *)make
{
    return [[MRChan alloc] initWithSize:0];
}

/**
 A chan with size 0 is an unbuffered channel.
 */
+ (MRChan *)make:(NSUInteger)size
{
    return [[MRChan alloc] initWithSize:size];
}

- (void)send:(id)object
{
    if (_buffered) // buffered channels only wait when full.
    {
        sem_wait(_sem_full);
        sem_wait(_sem_protected_send);
        _objects[_pos] = object;
        _pos = (_pos+1)%_buff_sz;
        sem_signal(_sem_protected_send);
        sem_signal(_sem_empty);
    }
    else
    {
        sem_wait(_sem_protected_send);
        _objects[0] = object;
        sem_signal(_sem_sent);
        sem_wait(_sem_received);
        sem_signal(_sem_protected_send);
    }
}

- (BOOL)trySend:(id)object
{
    long err;
    if (_buffered)
    {
        err = try_wait(_sem_full);
        if (err)
        {
            return FALSE;
        }
        
        err = try_wait(_sem_protected_send);
        if (err)
        {
            sem_signal(_sem_full);
            return FALSE;
        }
        _objects[_pos] = object;
        _pos = (_pos+1)%_buff_sz;
        sem_signal(_sem_protected_send);
        sem_signal(_sem_empty);
    }
    else
    {
        err = try_wait(_sem_protected_send);
        if (err)
        {
            return FALSE;
        }
        
        // We want the other semaphore to be waiting.
        err = try_wait(_sem_protected_receive);
        if (err == 0)
        {
            sem_signal(_sem_protected_send);
            sem_signal(_sem_protected_receive);
            return FALSE;
        }
        
        _objects[0] = object;
        sem_signal(_sem_sent);
        sem_wait(_sem_received);
        sem_signal(_sem_protected_send);
    }
    return TRUE;
}

- (void)receive:(id *)object
{
    if (_buffered)
    {
        sem_wait(_sem_empty);
        sem_wait(_sem_protected_receive);
        *object = _objects[_next];
        _next = (_next+1)%_buff_sz;
        sem_signal(_sem_protected_receive);
        sem_signal(_sem_full);
    }
    else
    {
        sem_wait(_sem_protected_receive);
        sem_wait(_sem_sent);
        *object = _objects[0];
        sem_signal(_sem_received);
        sem_signal(_sem_protected_receive);
    }
}

- (BOOL)tryReceive:(id *)object
{
    long err;
    if (_buffered)
    {
        err = try_wait(_sem_empty);
        if (err)
        {
            return FALSE;
        }
        
        err = try_wait(_sem_protected_receive);
        if (err)
        {
            sem_signal(_sem_empty);
            return FALSE;
        }
        
        *object = _objects[_next];
        _next = (_next+1)%_buff_sz;
        
        sem_signal(_sem_protected_receive);
        sem_signal(_sem_full);
    }
    else
    {
        err = try_wait(_sem_protected_receive);
        if (err)
        {
            return FALSE;
        }
        
        err = try_wait(_sem_sent);
        if (err)
        {
            sem_signal(_sem_protected_receive);
            return FALSE;
        }
        
        *object = _objects[0];
        sem_signal(_sem_received);
        sem_signal(_sem_protected_receive);
    }
    return TRUE;
}



@end
