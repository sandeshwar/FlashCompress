#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <iostream>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Get all available Metal devices
        NSArray<id<MTLDevice>> *devices = MTLCopyAllDevices();
        
        if ([devices count] == 0) {
            std::cout << "No Metal devices found on the system!" << std::endl;
            return 1;
        }
        
        std::cout << "Found " << [devices count] << " Metal device(s):" << std::endl;
        
        for (id<MTLDevice> device in devices) {
            std::cout << "Device: " << [[device name] UTF8String] << std::endl;
            std::cout << "  Unified Memory: " << (device.hasUnifiedMemory ? "Yes" : "No") << std::endl;
            std::cout << "  Low Power: " << (device.isLowPower ? "Yes" : "No") << std::endl;
            std::cout << "  Removable: " << (device.isRemovable ? "Yes" : "No") << std::endl;
            std::cout << "  Max Buffer Length: " << device.maxBufferLength << std::endl;
        }
        
        // Try to create default device
        id<MTLDevice> defaultDevice = MTLCreateSystemDefaultDevice();
        if (defaultDevice) {
            std::cout << "\nDefault Metal device: " << [[defaultDevice name] UTF8String] << std::endl;
        } else {
            std::cout << "\nFailed to create default Metal device!" << std::endl;
        }
    }
    return 0;
}
