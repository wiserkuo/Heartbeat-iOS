//
//  HRMViewController.h
//  HeartMonitor
//
//  Created by Main Account on 12/13/13.
//  Copyright (c) 2013 Razeware LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
@import CoreBluetooth;
@import QuartzCore;
#define RHYTHMPLUS_HRM_DEVICE_INFO_SERVICE_UUID @"180A"
#define RHYTHMPLUS_HRM_HEART_RATE_SERVICE_UUID @"180D"
#define RHYTHMPLUS_HRM_MEASUREMENT_CHARACTERISTIC_UUID @"2A37"
#define RHYTHMPLUS_HRM_BODY_LOCATION_CHARACTERISTIC_UUID @"2A38"
#define RHYTHMPLUS_HRM_MANUFACTURER_NAME_CHARCTERISTIC_UUID @"2A29"

@interface HRMViewController : UIViewController < CBCentralManagerDelegate , CBPeripheralDelegate >
@property (nonatomic,strong) CBCentralManager *centralManager;
@property (nonatomic,strong) CBPeripheral *rhythmplusHRMPeripheral;

// Properties for your Object controls
@property (nonatomic, strong) IBOutlet UIImageView *heartImage;
@property (nonatomic, strong) IBOutlet UITextView  *deviceInfo;

// Properties to hold data characteristics for the peripheral device
@property (nonatomic, strong) NSString   *connected;
@property (nonatomic, strong) NSString   *bodyData;
@property (nonatomic, strong) NSString   *manufacturer;
@property (nonatomic, strong) NSString   *rhythmplusDeviceData;
@property (assign) uint16_t heartRate;

// Properties to handle storing the BPM and heart beat
@property (nonatomic, strong) UILabel    *heartRateBPM;
@property (nonatomic, retain) NSTimer    *pulseTimer;

// Instance method to get the heart rate BPM information
- (void) getHeartBPMData:(CBCharacteristic *)characteristic error:(NSError *)error;

// Instance methods to grab device Manufacturer Name, Body Location
- (void) getManufacturerName:(CBCharacteristic *)characteristic;
- (void) getBodyLocation:(CBCharacteristic *)characteristic;

// Instance method to perform heart beat animations
- (void) doHeartBeat;

@end
