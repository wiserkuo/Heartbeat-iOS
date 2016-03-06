//
//  HRMViewController.m
//  HeartMonitor
//
//  Created by Main Account on 12/13/13.
//  Copyright (c) 2013 Razeware LLC. All rights reserved.
//

#import "HRMViewController.h"


@interface HRMViewController ()

@end

@implementation HRMViewController

#pragma mark - CBCentralManagerDelegate
// method called whenever you have successfully connected to the BLE peripheral
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    [peripheral setDelegate:self];
    [peripheral discoverServices:nil];
    self.connected = [NSString stringWithFormat:@"Connected: %@", peripheral.state == CBPeripheralStateConnected ? @"YES" : @"NO"];
    NSLog(@"%@", self.connected);
}

// CBCentralManagerDelegate - This is called with the CBPeripheral class as its main input parameter. This contains most of the information there is to know about a BLE peripheral.
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSString *localName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    if ([localName length] > 0) {
        NSLog(@"Found the heart rate monitor: %@", localName);
        [self.centralManager stopScan];
        self.rhythmplusHRMPeripheral = peripheral;
        peripheral.delegate = self;
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
    NSLog(@"Not found the heart rate monitor: %@", localName);
}

// method called whenever the device state changes.
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    // Determine the state of the peripheral
    if ([central state] == CBCentralManagerStatePoweredOff) {
        NSLog(@"CoreBluetooth BLE hardware is powered off");
    }
    else if ([central state] == CBCentralManagerStatePoweredOn) {
        NSLog(@"CoreBluetooth BLE hardware is powered on and ready");

           NSArray *services = @[[CBUUID UUIDWithString:RHYTHMPLUS_HRM_HEART_RATE_SERVICE_UUID], [CBUUID UUIDWithString:RHYTHMPLUS_HRM_DEVICE_INFO_SERVICE_UUID]];
           [self.centralManager scanForPeripheralsWithServices:services options:nil];
    }
    else if ([central state] == CBCentralManagerStateUnauthorized) {
        NSLog(@"CoreBluetooth BLE state is unauthorized");
    }
    else if ([central state] == CBCentralManagerStateUnknown) {
        NSLog(@"CoreBluetooth BLE state is unknown");
    }
    else if ([central state] == CBCentralManagerStateUnsupported) {
        NSLog(@"CoreBluetooth BLE hardware is unsupported on this platform");
    }
}

#pragma mark - CBPeripheralDelegate

// CBPeripheralDelegate - Invoked when you discover the peripheral's available services.
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *service in peripheral.services) {
        NSLog(@"Discovered service: %@", service.UUID);
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

// Invoked when you discover the characteristics of a specified service.
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if ([service.UUID isEqual:[CBUUID UUIDWithString:RHYTHMPLUS_HRM_HEART_RATE_SERVICE_UUID]])  {  // 1
        for (CBCharacteristic *aChar in service.characteristics)
        {
            // Request heart rate notifications
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:RHYTHMPLUS_HRM_MEASUREMENT_CHARACTERISTIC_UUID]]) { // 2
                [self.rhythmplusHRMPeripheral setNotifyValue:YES forCharacteristic:aChar];
                NSLog(@"Found heart rate measurement characteristic");
            }
            // Request body sensor location
            else if ([aChar.UUID isEqual:[CBUUID UUIDWithString:RHYTHMPLUS_HRM_BODY_LOCATION_CHARACTERISTIC_UUID]]) { // 3
                [self.rhythmplusHRMPeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found body sensor location characteristic");
            }
        }
    }
    // Retrieve Device Information Services for the Manufacturer Name
    if ([service.UUID isEqual:[CBUUID UUIDWithString:RHYTHMPLUS_HRM_DEVICE_INFO_SERVICE_UUID]])  { // 4
        for (CBCharacteristic *aChar in service.characteristics)
        {
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:RHYTHMPLUS_HRM_MANUFACTURER_NAME_CHARCTERISTIC_UUID]]) {
                [self.rhythmplusHRMPeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found a device manufacturer name characteristic");
            }
        }
    }
}

// Invoked when you retrieve a specified characteristic's value, or when the peripheral device notifies your app that the characteristic's value has changed.
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    // Updated value for heart rate measurement received
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RHYTHMPLUS_HRM_MEASUREMENT_CHARACTERISTIC_UUID]]) { // 1
        // Get the Heart Rate Monitor BPM
        [self getHeartBPMData:characteristic error:error];
    }
    // Retrieve the characteristic value for manufacturer name received
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RHYTHMPLUS_HRM_MANUFACTURER_NAME_CHARCTERISTIC_UUID]]) {  // 2
        [self getManufacturerName:characteristic];
    }
    // Retrieve the characteristic value for the body sensor location received
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RHYTHMPLUS_HRM_BODY_LOCATION_CHARACTERISTIC_UUID]]) {  // 3
        [self getBodyLocation:characteristic];
    }
    
    // Add your constructed device information to your UITextView
    self.deviceInfo.text = [NSString stringWithFormat:@"%@\n%@\n%@\n", self.connected, self.bodyData, self.manufacturer];  // 4
}

#pragma mark - CBCharacteristic helpers

// Instance method to get the heart rate BPM information
- (void) getHeartBPMData:(CBCharacteristic *)characteristic error:(NSError *)error
{
    // Get the Heart Rate Monitor BPM
    NSData *data = [characteristic value];      // 1
    const uint8_t *reportData = [data bytes];
    uint16_t bpm = 0;
    
    if ((reportData[0] & 0x01) == 0) {          // 2
        // Retrieve the BPM value for the Heart Rate Monitor
        bpm = reportData[1];
    }
    else {
        bpm = CFSwapInt16LittleToHost(*(uint16_t *)(&reportData[1]));  // 3
    }
    // Display the heart rate value to the UI if no error occurred
    if( (characteristic.value)  || !error ) {   // 4
        self.heartRate = bpm;
        self.heartRateBPM.text = [NSString stringWithFormat:@"%i bpm", bpm];
        self.heartRateBPM.font = [UIFont fontWithName:@"Futura-CondensedMedium" size:28];
        [self doHeartBeat];
        self.pulseTimer = [NSTimer scheduledTimerWithTimeInterval:(60. / self.heartRate) target:self selector:@selector(doHeartBeat) userInfo:nil repeats:NO];
    }
    return;
}
// Instance method to get the manufacturer name of the device
- (void) getManufacturerName:(CBCharacteristic *)characteristic
{
    NSString *manufacturerName = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];  // 1
    self.manufacturer = [NSString stringWithFormat:@"Manufacturer: %@", manufacturerName];    // 2
    return;
}
// Instance method to get the body location of the device
- (void) getBodyLocation:(CBCharacteristic *)characteristic
{
    NSData *sensorData = [characteristic value];         // 1
    uint8_t *bodyData = (uint8_t *)[sensorData bytes];
    if (bodyData ) {
        uint8_t bodyLocation = bodyData[0];  // 2
        self.bodyData = [NSString stringWithFormat:@"Body Location: %@", bodyLocation == 1 ? @"Chest" : @"Undefined"]; // 3
    }
    else {  // 4
        self.bodyData = [NSString stringWithFormat:@"Body Location: N/A"];
    }
    return;
}
// Helper method to perform a heartbeat animation
- (void)doHeartBeat {
    CALayer *layer = [self heartImage].layer;
    CABasicAnimation *pulseAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulseAnimation.toValue = [NSNumber numberWithFloat:1.1];
    pulseAnimation.fromValue = [NSNumber numberWithFloat:1.0];
    
    pulseAnimation.duration = 60. / self.heartRate / 2.;
    pulseAnimation.repeatCount = 1;
    pulseAnimation.autoreverses = YES;
    pulseAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    [layer addAnimation:pulseAnimation forKey:@"scale"];
    
    self.pulseTimer = [NSTimer scheduledTimerWithTimeInterval:(60. / self.heartRate) target:self selector:@selector(doHeartBeat) userInfo:nil repeats:NO];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    
    // Do any additional setup after loading the view, typically from a nib.
    self.rhythmplusDeviceData = nil;
    [self.view setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
    [self.heartImage setImage:[UIImage imageNamed:@"HeartImage"]];
    
    // Clear out textView
    [self.deviceInfo setText:@""];
    [self.deviceInfo setTextColor:[UIColor blueColor]];
    [self.deviceInfo setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
    [self.deviceInfo setFont:[UIFont fontWithName:@"Futura-CondensedMedium" size:25]];
    [self.deviceInfo setUserInteractionEnabled:NO];
    
    // Create your Heart Rate BPM Label
    self.heartRateBPM = [[UILabel alloc] initWithFrame:CGRectMake(55, 30, 75, 50)];
    [self.heartRateBPM setTextColor:[UIColor redColor]];
    [self.heartRateBPM setText:[NSString stringWithFormat:@"%i", 0]];
    [self.heartRateBPM setFont:[UIFont fontWithName:@"Futura-CondensedMedium" size:28]];
    [self.heartImage addSubview:self.heartRateBPM];
    // Scan for all available CoreBluetooth LE devices
    
     CBCentralManager *centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
     
     self.centralManager = centralManager;

    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
