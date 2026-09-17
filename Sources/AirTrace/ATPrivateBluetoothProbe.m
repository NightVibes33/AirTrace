#import "ATPrivateBluetoothProbe.h"
#import <CoreBluetooth/CoreBluetooth.h>

// Private CoreBluetooth methods are invoked dynamically. Declaring them on NSObject
// gives the compiler type information without importing or linking private headers.
@interface NSObject (ATCBDiscoveryPrivate)
- (void)setLabel:(NSString *)label;
- (void)setUseCase:(unsigned int)useCase;
- (void)setDiscoveryFlags:(unsigned long long)flags;
- (void)setBleScanRate:(int)rate;
- (void)addDiscoveryType:(int)type;
- (void)setDeviceFoundHandler:(void (^)(id device))handler;
- (void)setDeviceLostHandler:(void (^)(id device))handler;
- (void)setErrorHandler:(void (^)(NSError *error))handler;
- (void)setInterruptionHandler:(void (^)(void))handler;
- (void)setInvalidationHandler:(void (^)(void))handler;
- (void)activateWithCompletion:(void (^)(NSError * _Nullable error))completion;
- (void)invalidate;
@end

static id ATValue(id object, NSString *key) {
    if (!object) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *ATHex(NSData *data) {
    if (![data isKindOfClass:NSData.class] || data.length == 0) return @"";
    const unsigned char *bytes = data.bytes;
    NSMutableString *result = [NSMutableString stringWithCapacity:data.length * 2];
    for (NSUInteger i = 0; i < data.length; i++) {
        [result appendFormat:@"%02X", bytes[i]];
    }
    return result;
}

static void ATPut(NSMutableDictionary *dict, NSString *key, id value) {
    if (value && value != NSNull.null) dict[key] = value;
}

@interface ATPrivateBluetoothProbe ()
@property (nonatomic, strong, nullable) id discovery;
@property (nonatomic, readwrite, getter=isActive) BOOL active;
@end

@implementation ATPrivateBluetoothProbe

- (BOOL)isAvailable {
    return NSClassFromString(@"CBDiscovery") != Nil;
}

- (void)emitStatus:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.statusHandler) self.statusHandler(status);
    });
}

- (NSDictionary<NSString *, id> *)snapshotForDevice:(id)device {
    NSMutableDictionary<NSString *, id> *out = [NSMutableDictionary dictionary];

    NSArray<NSString *> *keys = @[
        @"identifier", @"name", @"model", @"modelUser", @"productName",
        @"productID", @"vendorID", @"deviceType", @"deviceFlags",
        @"discoveryFlags", @"internalFlags", @"bleRSSI", @"bleChannel",
        @"bleAdvertisementTimestamp", @"btAddress", @"leAdvName",
        @"findMyCaseIdentifier", @"findMyGroupIdentifier",
        @"proximityPairingProductID", @"proximityPairingOtherBudProductID",
        @"proximityPairingSubType", @"objectDiscoveryProductID",
        @"objectDiscoveryMode", @"objectDiscoveryBatteryState",
        @"batteryLevelMain", @"batteryLevelLeft", @"batteryLevelRight",
        @"batteryLevelCase"
    ];

    for (NSString *key in keys) ATPut(out, key, ATValue(device, key));

    NSData *manufacturer = ATValue(device, @"bleAppleManufacturerData");
    NSData *advertisement = ATValue(device, @"bleAdvertisementData");
    NSData *publicKey = ATValue(device, @"objectDiscoveryPublicKeyData");
    NSData *nearOwner = ATValue(device, @"objectDiscoveryNearOwnerID");
    NSData *addressData = ATValue(device, @"bleAddressData");

    if ([manufacturer isKindOfClass:NSData.class]) {
        out[@"appleManufacturerHex"] = ATHex(manufacturer);
        out[@"appleManufacturerLength"] = @(manufacturer.length);
    }
    if ([advertisement isKindOfClass:NSData.class]) {
        out[@"advertisementHex"] = ATHex(advertisement);
        out[@"advertisementLength"] = @(advertisement.length);
    }
    if ([publicKey isKindOfClass:NSData.class]) out[@"objectDiscoveryPublicKeyHex"] = ATHex(publicKey);
    if ([nearOwner isKindOfClass:NSData.class]) out[@"objectDiscoveryNearOwnerIDHex"] = ATHex(nearOwner);
    if ([addressData isKindOfClass:NSData.class]) out[@"bleAddressHex"] = ATHex(addressData);

    NSString *description = [device description];
    if (description) out[@"rawDescription"] = description;
    out[@"runtimeClass"] = NSStringFromClass([device class]);
    out[@"seenAt"] = @([[NSDate date] timeIntervalSince1970]);

    return out;
}

- (void)start {
    [self stop];

    Class cls = NSClassFromString(@"CBDiscovery");
    if (!cls) {
        [self emitStatus:@"CBDiscovery is not present on this iOS build."];
        return;
    }

    id discovery = [[cls alloc] init];
    if (!discovery) {
        [self emitStatus:@"CBDiscovery exists but could not be instantiated."];
        return;
    }
    self.discovery = discovery;

    if ([discovery respondsToSelector:@selector(setLabel:)]) {
        [discovery setLabel:@"AirTrace-FindNearbyRemote"];
    }
    if ([discovery respondsToSelector:@selector(setUseCase:)]) {
        [discovery setUseCase:589824]; // FindNearbyRemote
    }
    if ([discovery respondsToSelector:@selector(setDiscoveryFlags:)]) {
        [discovery setDiscoveryFlags:0x200000000ULL];
    }
    if ([discovery respondsToSelector:@selector(setBleScanRate:)]) {
        [discovery setBleScanRate:60];
    }
    if ([discovery respondsToSelector:@selector(addDiscoveryType:)]) {
        [discovery addDiscoveryType:14];
    }

    __weak typeof(self) weakSelf = self;
    if ([discovery respondsToSelector:@selector(setDeviceFoundHandler:)]) {
        [discovery setDeviceFoundHandler:^(id device) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            NSDictionary *snapshot = [self snapshotForDevice:device];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.deviceHandler) self.deviceHandler(snapshot);
            });
        }];
    }
    if ([discovery respondsToSelector:@selector(setDeviceLostHandler:)]) {
        [discovery setDeviceLostHandler:^(id device) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            NSString *identifier = ATValue(device, @"identifier") ?: @"unknown";
            [self emitStatus:[NSString stringWithFormat:@"System discovery lost device %@", identifier]];
        }];
    }
    if ([discovery respondsToSelector:@selector(setErrorHandler:)]) {
        [discovery setErrorHandler:^(NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self emitStatus:[NSString stringWithFormat:@"CBDiscovery error: %@", error]];
        }];
    }
    if ([discovery respondsToSelector:@selector(setInterruptionHandler:)]) {
        [discovery setInterruptionHandler:^{
            __strong typeof(weakSelf) self = weakSelf;
            [self emitStatus:@"CBDiscovery XPC connection interrupted."];
        }];
    }
    if ([discovery respondsToSelector:@selector(setInvalidationHandler:)]) {
        [discovery setInvalidationHandler:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.active = NO;
            [self emitStatus:@"CBDiscovery invalidated by iOS."];
        }];
    }

    if (![discovery respondsToSelector:@selector(activateWithCompletion:)]) {
        [self emitStatus:@"CBDiscovery exists but activateWithCompletion: is unavailable."];
        self.discovery = nil;
        return;
    }

    [self emitStatus:@"Activating Apple FindNearbyRemote discovery…"];
    [discovery activateWithCompletion:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (error) {
            self.active = NO;
            [self emitStatus:[NSString stringWithFormat:@"Activation denied/failed: %@", error]];
        } else {
            self.active = YES;
            [self emitStatus:@"Apple FindNearbyRemote discovery active. Waiting for CBDevice samples…"];
        }
    }];
}

- (void)stop {
    id discovery = self.discovery;
    self.discovery = nil;
    self.active = NO;
    if (discovery && [discovery respondsToSelector:@selector(invalidate)]) {
        [discovery invalidate];
    }
}

- (void)dealloc {
    [self stop];
}

@end
