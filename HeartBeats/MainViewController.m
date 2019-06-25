//
//  MainViewController.m
//  HeartBeats
//
//  Created by Christian Roman on 30/08/13.
//  Copyright (c) 2013 Christian Roman. All rights reserved.
//

#import "MainViewController.h"

@interface MainViewController ()
{
    AVCaptureSession *session;
    CALayer* imageLayer;
    NSMutableArray *points;
}

@end

@implementation MainViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
//    imageLayer = [CALayer layer];
//    imageLayer.frame = self.view.layer.bounds;
//    imageLayer.contentsGravity = kCAGravityResizeAspectFill;
//    [self.view.layer addSublayer:imageLayer];

    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 100, 30)];
    [button addTarget:self action:@selector(flashActive) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    button.backgroundColor = [UIColor grayColor];
    [button setTitle:@"开始测量" forState:UIControlStateNormal];

//    [self setupAVCapture];
    [self flashActive];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self stopAVCapture];
}

- (void)configureCameraForHighestFrameRate:(AVCaptureDevice *)device
{
    AVCaptureDeviceFormat *bestFormat = nil;
    AVFrameRateRange *bestFrameRateRange = nil;
    for ( AVCaptureDeviceFormat *format in [device formats] ) {
        for ( AVFrameRateRange *range in format.videoSupportedFrameRateRanges ) {
            if ( range.maxFrameRate > bestFrameRateRange.maxFrameRate ) {
                bestFormat = format;
                bestFrameRateRange = range;
            }
        }
    }
    if ( bestFormat ) {
        if ( [device lockForConfiguration:NULL] == YES ) {
            device.activeFormat = bestFormat;
            device.activeVideoMinFrameDuration = bestFrameRateRange.minFrameDuration;
            device.activeVideoMaxFrameDuration = bestFrameRateRange.minFrameDuration;
        }
    }


    device.activeVideoMinFrameDuration = CMTimeMake(1, (int)200);
    device.activeVideoMaxFrameDuration =  CMTimeMake(1, (int)200);
}

- (void)setupAVCapture
{
    // Get the default camera device
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    // Create the AVCapture Session
    session = [AVCaptureSession new];

    [session beginConfiguration];

    // Create a AVCaptureDeviceInput with the camera device
    NSError *error = nil;
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (error) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Error %d", (int)[error code]]
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
        //[self teardownAVCapture];
        return;
    }

    if ([session canAddInput:deviceInput])
        [session addInput:deviceInput];


	if([device isTorchModeSupported:AVCaptureTorchModeOn]) {
        
        [self configureCameraForHighestFrameRate:device];
//        [device setTorchMode:AVCaptureTorchModeOn];
//        [device setTorchModeOnWithLevel:1.0 error:nil];
	}

    AVCaptureVideoDataOutput *videoDataOutput = [AVCaptureVideoDataOutput new];
	NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
									   [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
	[videoDataOutput setVideoSettings:rgbOutputSettings];
	[videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
	dispatch_queue_t videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
	[videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    
    if ([session canAddOutput:videoDataOutput])
		[session addOutput:videoDataOutput];
    AVCaptureConnection* connection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];

    [session commitConfiguration];
    [session startRunning];

}

- (void) flashActive{
    [self setupAVCapture];
    AVCaptureDevice * currentDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if(currentDevice.hasTorch) {
        [currentDevice lockForConfiguration:nil];
        BOOL torchOn = !currentDevice.isTorchActive;
        [currentDevice setTorchModeOnWithLevel:1.0 error:nil];
        currentDevice.torchMode = torchOn ? AVCaptureTorchModeOn : AVCaptureTorchModeOff;
        [currentDevice unlockForConfiguration];
    }

}

- (void)stopAVCapture
{
    [session stopRunning];
    session = nil;
    points = nil;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    uint8_t *buf = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    int32_t sr = 0;
    for(int y = 0; y < height; y++) {
        for(int x = 0; x < width * 4; x += 4) {
            sr+=buf[x+2];
        }
        buf += bytesPerRow;
    }
//    printf("%d\n",sr);
    NSLog(@"%d",sr);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);

}

@end
