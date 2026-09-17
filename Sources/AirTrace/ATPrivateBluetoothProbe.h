#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ATPrivateDiscoveryDeviceHandler)(NSDictionary<NSString *, id> *device);
typedef void (^ATPrivateDiscoveryStatusHandler)(NSString *status);

@interface ATPrivateBluetoothProbe : NSObject
@property (nonatomic, copy, nullable) ATPrivateDiscoveryDeviceHandler deviceHandler;
@property (nonatomic, copy, nullable) ATPrivateDiscoveryStatusHandler statusHandler;
@property (nonatomic, readonly, getter=isAvailable) BOOL available;
@property (nonatomic, readonly, getter=isActive) BOOL active;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
