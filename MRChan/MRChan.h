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


#import <Foundation/Foundation.h>

@interface MRChan : NSObject

/**
 Create an unbuffered channel.
 */
+ (MRChan *)make;

/**
 Create a buffered channel.  If (|size| == 0) then the channel is unbuffered.
 */
+ (MRChan *)make:(NSUInteger)size;

/**
 for buffered channels: wait until the buffer is not full.
 for unbuffered channels: wait until the channel is ready to receive |object|.
 */
- (void)send:(id)object;

/**
 for buffered channels: wait until the buffer is not empty. Then set object to buffered value.
 for unbuffered channels: wait until channel is ready to send.
 */
- (void)receive:(id *)object;

/**
 If the channel can be sent on NOW, then send.
 Returns whether or not the object was sent.
 */
- (BOOL)trySend:(id)object;

/**
 If the channel can receive an object NOW, then receive the object.
 Returns whether or not the object was received.
 */
- (BOOL)tryReceive:(id *)object;

@end
