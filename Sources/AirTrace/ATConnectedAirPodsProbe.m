#import "ATConnectedAirPodsProbe.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static id ATValue(id object, NSString *key) {
    if (!object || !key.length) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static id ATCallObject0(id object, NSString *selectorName) {
    if (!object) return nil;
    SEL sel = NSSelectorFromString(selectorName);
    if (![object respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, sel);
}

static BOOL ATCallBool0(id object, NSString *selectorName, BOOL fallback) {
    if (!object) return fallback;
    SEL sel = NSSelectorFromString(selectorName);
    if (![object respondsToSelector:sel]) return fallback;
    return ((BOOL (*)(id, SEL))objc_msgSend)(object, sel);
}

static unsigned long long ATCallUInt0(id object, NSString *selectorName, unsigned long long fallback) {
    if (!object) return fallback;
    SEL sel = NSSelectorFromString(selectorName);
    if (![object respondsToSelector:sel]) return fallback;
    return ((unsigned long long (*)(id, SEL))objc_msgSend)(object, sel);
}

static double ATNumber(id value, double fallback) {
    return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : fallback;
}

static NSString *ATHex(NSData *data) {
    if (![data isKindOfClass:NSData.class] || data.length == 0) return @"";
    const unsigned char *bytes = data.bytes;
    NSMutableString *result = [NSMutableString stringWithCapacity:data.length * 2];
    for (NSUInteger i = 0; i < data.length; i++) [result appendFormat:@"%02X", bytes[i]];
    return result;
}

static void ATPut(NSMutableDictionary *dict, NSString *key, id value) {
    if (value && value != NSNull.null) dict[key] = value;
}

static NSDictionary *ATSnapshotCBDevice(id device) {
    if (!device) return @{};
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
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
        @"batteryLevelCase", @"classicRSSI"
    ];
    for (NSString *key in keys) ATPut(out, key, ATValue(device, key));

    NSDictionary<NSString *, NSString *> *dataKeys = @{
        @"bleAppleManufacturerData": @"appleManufacturerHex",
        @"bleAdvertisementData": @"advertisementHex",
        @"objectDiscoveryPublicKeyData": @"objectDiscoveryPublicKeyHex",
        @"objectDiscoveryNearOwnerID": @"objectDiscoveryNearOwnerIDHex",
        @"bleAddressData": @"bleAddressHex"
    };
    [dataKeys enumerateKeysAndObjectsUsingBlock:^(NSString *source, NSString *dest, BOOL *stop) {
        NSData *data = ATValue(device, source);
        if ([data isKindOfClass:NSData.class]) out[dest] = ATHex(data);
    }];
    out[@"runtimeClass"] = NSStringFromClass([device class]) ?: @"unknown";
    NSString *description = [device description];
    if (description) out[@"rawDescription"] = description;
    return out;
}

static NSDictionary *ATSnapshotHPMDevice(id device) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    ATPut(out, @"name", ATValue(device, @"name"));
    ATPut(out, @"btAddress", ATValue(device, @"btAddress"));
    ATPut(out, @"isAirpods", ATValue(device, @"isAirpods"));
    ATPut(out, @"batteryLevelMain", ATValue(device, @"batteryLevelMain"));
    ATPut(out, @"batteryLevelLeft", ATValue(device, @"batteryLevelLeft"));
    ATPut(out, @"batteryLevelRight", ATValue(device, @"batteryLevelRight"));
    ATPut(out, @"batteryLevelCase", ATValue(device, @"batteryLevelCase"));
    ATPut(out, @"findMyNetworkSupport", ATValue(device, @"findMyNetworkSupport"));
    ATPut(out, @"findMyNetworkEnable", ATValue(device, @"findMyNetworkEnable"));
    ATPut(out, @"serialNumbers", ATValue(device, @"serialNumbers"));
    ATPut(out, @"runtimeClass", NSStringFromClass([device class]));

    id cbDevice = ATCallObject0(device, @"cbDevice");
    if (!cbDevice) {
        id service = ATCallObject0(device, @"airPodsServiceClient");
        cbDevice = ATCallObject0(service, @"peerDevice");
    }
    if (cbDevice) out[@"cbDevice"] = ATSnapshotCBDevice(cbDevice);
    return out;
}

static NSDictionary *ATSnapshotBluetoothDevice(id device) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    ATPut(out, @"name", ATCallObject0(device, @"name"));
    ATPut(out, @"productName", ATCallObject0(device, @"productName"));
    ATPut(out, @"address", ATCallObject0(device, @"address"));
    out[@"connected"] = @(ATCallBool0(device, @"connected", NO));
    out[@"paired"] = @(ATCallBool0(device, @"paired", NO));
    out[@"isAppleAudioDevice"] = @(ATCallBool0(device, @"isAppleAudioDevice", NO));
    out[@"isGenuineAirPods"] = @(ATCallBool0(device, @"isGenuineAirPods", NO));
    out[@"productId"] = @(ATCallUInt0(device, @"productId", 0));
    out[@"vendorId"] = @(ATCallUInt0(device, @"vendorId", 0));
    out[@"batteryLevel"] = @(ATCallUInt0(device, @"batteryLevel", 0));
    out[@"runtimeClass"] = NSStringFromClass([device class]) ?: @"unknown";
    NSString *description = [device description];
    if (description) out[@"rawDescription"] = description;
    return out;
}

static NSArray *ATArrayFromCollection(id value) {
    if ([value isKindOfClass:NSArray.class]) return value;
    if ([value isKindOfClass:NSDictionary.class]) return [(NSDictionary *)value allValues];
    if ([value respondsToSelector:@selector(allObjects)]) {
        id objects = ATCallObject0(value, @"allObjects");
        if ([objects isKindOfClass:NSArray.class]) return objects;
    }
    return @[];
}

@implementation ATConnectedAirPodsProbe {
    void *_headphoneHandle;
    void *_bluetoothManagerHandle;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _headphoneHandle = dlopen("/System/Library/PrivateFrameworks/HeadphoneManager.framework/HeadphoneManager", RTLD_NOW | RTLD_LOCAL);
        _bluetoothManagerHandle = dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_NOW | RTLD_LOCAL);
    }
    return self;
}

- (BOOL)headphoneManagerAvailable {
    return NSClassFromString(@"HPMHeadphoneManager") != Nil;
}

- (BOOL)bluetoothManagerAvailable {
    return NSClassFromString(@"BluetoothManager") != Nil;
}

- (NSDictionary<NSString *, id> *)snapshot {
    NSMutableDictionary *root = [NSMutableDictionary dictionary];
    root[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    root[@"headphoneManagerLoaded"] = @(self.headphoneManagerAvailable);
    root[@"bluetoothManagerLoaded"] = @(self.bluetoothManagerAvailable);

    const char *hpmError = _headphoneHandle ? NULL : dlerror();
    const char *btmError = _bluetoothManagerHandle ? NULL : dlerror();
    if (hpmError) root[@"headphoneManagerLoadError"] = [NSString stringWithUTF8String:hpmError];
    if (btmError) root[@"bluetoothManagerLoadError"] = [NSString stringWithUTF8String:btmError];

    Class hpClass = NSClassFromString(@"HPMHeadphoneManager");
    id hpManager = hpClass ? ATCallObject0((id)hpClass, @"shared") : nil;
    root[@"headphoneManagerInstance"] = @(hpManager != nil);

    if (hpManager) {
        id connected = ATCallObject0(hpManager, @"connectedHeadphones");
        id paired = ATCallObject0(hpManager, @"pairedHeadphones");
        NSMutableArray *connectedOut = [NSMutableArray array];
        for (id device in ATArrayFromCollection(connected)) [connectedOut addObject:ATSnapshotHPMDevice(device)];
        NSMutableArray *pairedOut = [NSMutableArray array];
        for (id device in ATArrayFromCollection(paired)) [pairedOut addObject:ATSnapshotHPMDevice(device)];
        root[@"hpmConnected"] = connectedOut;
        root[@"hpmPaired"] = pairedOut;
    }

    Class btClass = NSClassFromString(@"BluetoothManager");
    id btManager = btClass ? ATCallObject0((id)btClass, @"sharedInstance") : nil;
    root[@"bluetoothManagerInstance"] = @(btManager != nil);

    if (btManager) {
        id connected = ATCallObject0(btManager, @"connectedDevices");
        id paired = ATCallObject0(btManager, @"pairedDevices");
        NSMutableArray *connectedOut = [NSMutableArray array];
        for (id device in ATArrayFromCollection(connected)) [connectedOut addObject:ATSnapshotBluetoothDevice(device)];
        NSMutableArray *pairedOut = [NSMutableArray array];
        for (id device in ATArrayFromCollection(paired)) [pairedOut addObject:ATSnapshotBluetoothDevice(device)];
        root[@"btmConnected"] = connectedOut;
        root[@"btmPaired"] = pairedOut;
        root[@"bluetoothManagerAudioConnected"] = @(ATCallBool0(btManager, @"audioConnected", NO));
        root[@"bluetoothManagerConnected"] = @(ATCallBool0(btManager, @"connected", NO));
        root[@"bluetoothManagerPowered"] = @(ATCallBool0(btManager, @"powered", NO));
    }

    return root;
}

- (void)dealloc {
    if (_headphoneHandle) dlclose(_headphoneHandle);
    if (_bluetoothManagerHandle) dlclose(_bluetoothManagerHandle);
}

@end
