#if __has_include(<Foundation/Foundation.h>)
#import <Foundation/Foundation.h>

@interface JSCoreExtrasFileHandle: NSObject

- (instancetype) initWithURL:(NSURL *) url error:(NSError **) error;

- (NSData *) readFromOffset:(uint64_t) offset count:(uint64_t) count error:(NSError **)error;

@end
#endif
