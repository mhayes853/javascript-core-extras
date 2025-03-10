#if __has_include(<Foundation/Foundation.h>)
#import "include/JSCoreExtrasFileHandle.h"

@implementation JSCoreExtrasFileHandle {
  NSFileHandle *handle;
}

- (instancetype) initWithURL:(NSURL *)url error:(NSError **)error {
  self = [super init];
  if (!self) return nil;
  NSError *fileError;
  handle = [NSFileHandle fileHandleForReadingFromURL:url error:&fileError];
  if (!handle) {
      if (fileError) *error = fileError;
      return nil;
  }
  return self;
}

- (NSData *) readFromOffset:(uint64_t) offset count:(uint64_t) count error:(NSError **)error {
  NSError *fileError;
  BOOL didSeek = [handle seekToOffset:offset error:&fileError];
  if (!didSeek) {
    if (fileError) *error = fileError;
    return nil;
  }
  fileError = nil;
  NSData *data = [handle readDataUpToLength:count error:&fileError];
  if (!data) {
    if (fileError) *error = fileError;
    return nil;
  }
  return data;
}

@end
#endif
