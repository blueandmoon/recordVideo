//
//  avRecordVideoController.m
//  recordVideo
//
//  Created by 李根 on 16/8/24.
//  Copyright © 2016年 ligen. All rights reserved.
//

#import "avRecordVideoController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

@interface avRecordVideoController ()<AVCaptureFileOutputRecordingDelegate>
@property(nonatomic, strong)AVCaptureSession *captureSession;   //  负责输入和输出设备之间的数据传递
@property(nonatomic, strong)AVCaptureDeviceInput *captureDeviceInput;   //  负责从AVDeviceCapture获得输入数据
@property(nonatomic, strong)AVCaptureMovieFileOutput *captureMovieFileOutput;   //  视频输出流
@property(nonatomic, strong)AVCaptureStillImageOutput *capturesStillImageOutput;    //  照片输出流
@property(nonatomic, strong)AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;   //  相机拍摄预览图层

@property(nonatomic, assign)BOOL enableRotation;    //  是否允许旋转
@property(nonatomic, assign)CGRect lastBounds;  //  旋转前的大小
@property(nonatomic, assign)UIBackgroundTaskIdentifier backgroundTaskIdentifier;    //  后台任务标识
@property(nonatomic, strong)UIView *viewContainer;  //
@property(nonatomic, strong)UIButton *toggleCameraBtn;  //  切换前后摄像头
@property(nonatomic, strong)UIButton *takeBtn;  //  拍照按钮
@property(nonatomic, strong)UIButton *recordBtn;    //  录制按钮
@property(nonatomic, strong)UIButton *flashAutoBtn; //  自动闪光按钮
@property(nonatomic, strong)UIButton *flashOnBtn;   //  打开闪光按钮
@property(nonatomic, strong)UIButton *flashOffBtn;  //  关闭闪光按钮
@property(nonatomic, strong)UIImageView *focusCursor;   //  聚焦光标

@end

@implementation avRecordVideoController

#pragma mark    - viewWillAppear
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    //  初始化会话
    _captureSession = [[AVCaptureSession alloc] init];
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) { //  设置分辨率
        _captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    }
    [self addNotificationToCaptureSession:_captureSession];
    
    //  获取输入设备
    AVCaptureDevice *captureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];    //  取得后置摄像头
    if (!captureDevice) {
        NSLog(@"取得后置摄像头出现问题~");
        return;
    }
    
    //  添加一个音频输入设备
    AVCaptureDevice *audioCaptureDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    NSError *error = nil;
    //  根据输入设备初始化设备输入对象, 用于获得输入数据
    _captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错, 错误原因: %@", error.localizedDescription);
        return;
    }
    AVCaptureDeviceInput *audioCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioCaptureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错, 错误原因: %@", error.localizedDescription);
        return;
    }
    //  初始化设备输出对象, 用于获取输出对象
    _captureMovieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    
    //  将设备输入添加到会话中
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
        [_captureSession addInput:audioCaptureDeviceInput];
        AVCaptureConnection *captureConnection = [_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([captureConnection isVideoMirroringSupported]) {
            captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;    //  stabilization 稳定, 稳定化
        }
    }
    
    //  将设备输出添加到会话中
    if ([_captureSession canAddOutput:_captureMovieFileOutput]) {
        [_captureSession addOutput:_captureMovieFileOutput];
    }
    
    //  创建视频预览层, 用于实时展示摄像头的状态
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    CALayer *layer = self.viewContainer.layer;
    layer.masksToBounds = YES;
    _captureVideoPreviewLayer.frame = layer.bounds;
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;   //  填充模式
    //  将视频预览层添加到界面中
//    [layer addSublayer:_captureVideoPreviewLayer];
    [layer insertSublayer:_captureVideoPreviewLayer below:_focusCursor.layer];
    
    _enableRotation = YES;
    [self addNotificationToCaptureDevice:captureDevice];
    [self addGestureRecognizer];
//    [self setFlashModeButtonStatus];
    
    
}

/**
 *  设置闪光灯按钮状态
 */
- (void)setFlashModeButtonStatus {
    AVCaptureDevice *currentDevice = [self.captureDeviceInput device];
    AVCaptureFlashMode flashMode = currentDevice.flashMode;
    if ([currentDevice isFlashAvailable]) {
        self.flashAutoBtn.hidden = NO;
        self.flashOffBtn.hidden = NO;
        self.flashOnBtn.hidden = NO;
        self.flashAutoBtn.enabled = YES;
        self.flashOffBtn.enabled = YES;
        self.flashOnBtn.enabled = YES;
        
        switch (flashMode) {
            case AVCaptureFlashModeAuto:
                self.flashAutoBtn.enabled = NO;
                break;
            case AVCaptureFlashModeOn:
                self.flashOnBtn.enabled = NO;
                break;
                case AVCaptureFlashModeOff:
            self.flashOffBtn.enabled = NO;
                break;
                
            default:
                break;
        }
        
    } else {
        self.flashOnBtn.hidden = YES;
        self.flashOffBtn.hidden = YES;
        self.flashAutoBtn.hidden = YES;
    }
    
}

/**
 *  改变设备属性的统一方法
 *
 *  @param propertyChange 属性改变操作
 */
- (void)changeDeviceProperty:(PropertyChangeBlock)propertyChange {
    AVCaptureDevice *captureDevice = [self.captureDeviceInput device];
    NSError *error;
    //  注意改变设备属性前一定要先调用lockForConfiguration: 调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    } else {
        NSLog(@"设置设备属性过程中发生错误, 错误原因: %@", error.localizedDescription);
    }
    
}

/**
 *  添加点按手势, 点按时聚焦
 */
- (void)addGestureRecognizer {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapScreen:)];
    [_viewContainer addGestureRecognizer:tap];
}

- (void)tapScreen:(UITapGestureRecognizer *)tapGesture {
    CGPoint point = [tapGesture locationInView:_viewContainer];
    //  将UI坐标转化为摄像头坐标
    CGPoint cameraPoint = [self.captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorWithPoint:point];

    
}

/**
 *  设置曝光模式
 *
 *  @param exposureMode 曝光模式
 */
- (void)setExposureMode:(AVCaptureExposureMode)exposureMode {
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
    }];
}

/**
 *  设置闪光模式
 *
 *  @param flashMode 闪光模式
 */
- (void)setFlashMode:(AVCaptureFlashMode)flashMode {
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFlashModeSupported:flashMode]) {
            [captureDevice setFlashMode:flashMode];
        }
    }];
}

/**
 *  设置聚焦模式
 *
 *  @param focusMode 聚焦模式
 */
- (void)setFocusMode:(AVCaptureFocusMode)focusMode {
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
    }];
}

/**
 *  设置聚焦点
 *
 *  @param focusModel   聚焦模式
 *  @param exposureMode 曝光模式
 *  @param point        聚焦点
 */
- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point {
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
       
    }];
}

/**
 *  设置聚焦光标位置
 *
 *  @param point 光标位置
 */
- (void)setFocusCursorWithPoint:(CGPoint)point {
    self.focusCursor.center = point;
    self.focusCursor.transform = CGAffineTransformMakeScale(1.5, 1.5);
    self.focusCursor.alpha = 1.0;
    [UIView animateWithDuration:1.0 animations:^{
        self.focusCursor.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.focusCursor.alpha = 0;
    }];
    
}

#pragma mark    - 给输入设备添加通知
- (void)addNotificationToCaptureDevice:(AVCaptureDevice *)captureDevice {
    //  注意添加区域改变捕获通知必须首先设置设备允许捕获
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        captureDevice.subjectAreaChangeMonitoringEnabled = YES;
    }];
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    //  捕获区域发生改变
    [notificationCenter addObserver:self selector:@selector(areaChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
    
}

- (void)removeNotificationFromCaptureDevice:(AVCaptureDevice *)captureDevice {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}

/**
 *  移除所有通知
 */
- (void)removeNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)addNotificationToCaptureSession:(AVCaptureSession *)captureSession {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    //  会话出错
    [notificationCenter addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:captureSession];
}

/**
 *  设备连接成功
 *
 *  @param notification 通知对象
 */
- (void)deviceConnected:(NSNotification *)notification {
    NSLog(@"设备已连接...");
}


/**
 *  设备连接断开
 *
 *  @param notification 通知对象
 */
- (void)deviceDisconnected:(NSNotification *)notification {
    NSLog(@"设备连接已断开...");
}

/**
 *  捕获区域改变
 *
 *  @param notification 通知对象
 */
- (void)areaChange:(NSNotification *)notification {
//    NSLog(@"捕获区域改变...");
}

/**
 *  会话错误
 *
 *  @param notification 通知对象
 */
- (void)sessionRuntimeError:(NSNotification *)notification {
    NSLog(@"会话发生错误...");
}

/**
 *  取得指定的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition)position {
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position] == position) {
            return camera;
        }
    }
    return nil;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [_captureSession startRunning];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_captureSession stopRunning];
}

- (BOOL)shouldAutorotate {
    return _enableRotation;
}

////屏幕旋转时调整视频预览图层的方向
//-(void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
//    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
////    NSLog(@"%i,%i",newCollection.verticalSizeClass,newCollection.horizontalSizeClass);
//    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
//    NSLog(@"%i",orientation);
//    AVCaptureConnection *captureConnection=[self.captureVideoPreviewLayer connection];
//    captureConnection.videoOrientation=orientation;
//
//}

//  屏幕旋转时跳转视频预览图层的方向
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    AVCaptureConnection *captureConnection = [self.captureVideoPreviewLayer connection];
    captureConnection.videoOrientation = (AVCaptureVideoOrientation)toInterfaceOrientation;
}

//  旋转后重新设置大小
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    _captureVideoPreviewLayer.frame = _viewContainer.bounds;
}

- (void)dealloc {
    [self removeNotification];
}

#pragma mark    - viewDidLoad
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    
    //  一些视图建立
    [self setView];
    
    
    /**
     *  源链接: http://www.cnblogs.com/kenshincui/p/4186022.html#uiImagePickerController
     *
     *  @param void 使用avfoundation录制视频
     *
     *
     */
    
    
    
}

- (void)setView {
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:backBtn];
    backBtn.frame = CGRectMake(20, 30, 50, 30);
    [backBtn setTitle:@"back" forState:UIControlStateNormal];
    backBtn.backgroundColor = [UIColor cyanColor];
    [backBtn addTarget:self action:@selector(back:) forControlEvents:UIControlEventTouchUpInside];
    
    _recordBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:_recordBtn];
    _recordBtn.frame = CGRectMake(220, 30, 100, 30);
    [_recordBtn setTitle:@"录制视频" forState:UIControlStateNormal];
    _recordBtn.backgroundColor = [UIColor purpleColor];
    [_recordBtn addTarget:self action:@selector(startRecordVideo:) forControlEvents:UIControlEventTouchUpInside];
    
    _toggleCameraBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:_toggleCameraBtn];
    _toggleCameraBtn.frame = CGRectMake(100, 30, 100, 30);
    [_toggleCameraBtn setTitle:@"切换摄像头" forState:UIControlStateNormal];
    _toggleCameraBtn.backgroundColor = [UIColor orangeColor];
    [_toggleCameraBtn addTarget:self action:@selector(toggleCamera:) forControlEvents:UIControlEventTouchUpInside];
    
    _flashAutoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:_flashAutoBtn];
    _flashAutoBtn.frame = CGRectMake(20, 500, 100, 30);
    [_flashAutoBtn setTitle:@"flashAuto" forState:UIControlStateNormal];
    _flashAutoBtn.backgroundColor = [UIColor orangeColor];
    [_flashAutoBtn addTarget:self action:@selector(flashAuto:) forControlEvents:UIControlEventTouchUpInside];
    
    _flashOnBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:_flashOnBtn];
    _flashOnBtn.frame = CGRectMake(125, 500, 100, 30);
    [_flashOnBtn setTitle:@"flashOn" forState:UIControlStateNormal];
    _flashOnBtn.backgroundColor = [UIColor orangeColor];
    [_flashOnBtn addTarget:self action:@selector(flashOn:) forControlEvents:UIControlEventTouchUpInside];
    
    _flashOffBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:_flashOffBtn];
    _flashOffBtn.frame = CGRectMake(230, 500, 100, 30);
    [_flashOffBtn setTitle:@"flashOff" forState:UIControlStateNormal];
    _flashOffBtn.backgroundColor = [UIColor orangeColor];
    [_flashOffBtn addTarget:self action:@selector(flashOff:) forControlEvents:UIControlEventTouchUpInside];
    
    _viewContainer = [[UIView alloc] initWithFrame:CGRectMake(30, 150, 200, 200)];
    [self.view addSubview:_viewContainer];
    _viewContainer.layer.borderWidth = 1;
}

#pragma mark    - 打开闪光灯
- (void)flashOn:(id)sender {
    [self setFlashMode:AVCaptureFlashModeOn];
    [self setFlashModeButtonStatus];
}

#pragma mark    - 关闭闪光灯
- (void)flashOff:(id)sender {
    [self setFlashMode:AVCaptureFlashModeOff];
    [self setFlashModeButtonStatus];
    
}

#pragma mark    - 自动闪光灯开启
- (void)flashAuto:(id)sender {
    [self setFlashMode:AVCaptureFlashModeAuto];
    [self setFlashModeButtonStatus];
}

#pragma mark    - 开始/结束 视频录制
- (void)startRecordVideo:(id)sender {
    NSLog(@"开始录制btn...");
    //  根据输出设备获得连接
    AVCaptureConnection *captureConnection = [_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    //  根据连接取得设备输出的数据
    if (![_captureMovieFileOutput isRecording]) {
        _enableRotation = NO;
        //  如果支持多任务则开始多任务
        if ([[UIDevice currentDevice] isMultitaskingSupported]) {
            self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
        }
        
        //  预览图层与视频方向保持一致
        captureConnection.videoOrientation = [self.captureVideoPreviewLayer connection].videoOrientation;
        NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingString:@"myMovie.mov"];
        NSLog(@"savePath is %@", outputFilePath);
        NSURL *fileUrl = [NSURL fileURLWithPath:outputFilePath];
        [self.captureMovieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
    } else {
        [self.captureMovieFileOutput stopRecording];
    }
    
}

#pragma mark    - 切换前后摄像头
- (void)toggleCamera:(id)sender {
    
    AVCaptureDevice *currentDevice = [self.captureDeviceInput device];
    AVCaptureDevicePosition currentPosition = [currentDevice position];
    [self removeNotificationFromCaptureDevice:currentDevice];
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition = AVCaptureDevicePositionFront;
    
    if (currentPosition == AVCaptureDevicePositionUnspecified || currentPosition == AVCaptureDevicePositionFront) {
        toChangePosition = AVCaptureDevicePositionBack;
    }
    toChangeDevice = [self getCameraDeviceWithPosition:toChangePosition];
    [self addNotificationToCaptureDevice:toChangeDevice];
    //  获取要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:toChangeDevice error:nil];
    
    //  改变会话的配置前一定要先开启配置, 配置完成后提交配置改变
    [self.captureSession beginConfiguration];
    
    //  移除原有输入对象
    [self.captureSession removeInput:self.captureDeviceInput];
    //  添加新的输入对象
    if ([self.captureSession canAddInput:toChangeDeviceInput]) {
        [self.captureSession addInput:toChangeDeviceInput];
        self.captureDeviceInput = toChangeDeviceInput;
    }
    [self.captureSession commitConfiguration];
    
    [self setFlashModeButtonStatus];
    
}

#pragma mark    - 视频输出代理
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections {
    NSLog(@"开始录制...");
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    NSLog(@"视频录制完成...");
    //  视频录制完成后再后台将视频存储到相册
    _enableRotation = YES;
    UIBackgroundTaskIdentifier lastBackgroundTaskIdentifier = self.backgroundTaskIdentifier;
    self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    ALAssetsLibrary *assetsLibrary = [[ALAssetsLibrary alloc] init];
    [assetsLibrary writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            NSLog(@"保存视频到相册过程中发生错误, 原因: %@", error.localizedDescription);
        }
        if (lastBackgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:lastBackgroundTaskIdentifier];
        }
        NSLog(@"成功保存到相册...");
        
    }];
    
    
}

- (void)back:(id)sender {   //  返回
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
