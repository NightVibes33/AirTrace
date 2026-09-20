#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ATConnectedAirPodsProbe : NSObject
@property (nonatomic, readonly) BOOL headphoneManagerAvailable;
@property (nonatomic, readonly) BOOL bluetoothManagerAvailable;
- (NSDictionary<NSString *, id> *)snapshot;
@end

NS_ASSUME_NONNULL_END
