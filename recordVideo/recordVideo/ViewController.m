//
//  ViewController.m
//  recordVideo
//
//  Created by 李根 on 16/8/23.
//  Copyright © 2016年 ligen. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "avRecordVideoController.h"

@interface ViewController ()<UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property(nonatomic, assign)BOOL isVideo;   //  是否录制视频, 1表示录制视频, 0代表拍照
@property(nonatomic, strong)UIImagePickerController *imagePicker;
@property(nonatomic, strong)UIImageView *photo; //  照片展示图
@property(nonatomic, strong)AVPlayer *player;   //  播放器, 用于录制完后播放视频

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.view.backgroundColor = [UIColor whiteColor];
    
    //  这是设置是录制视频还是拍照
    _isVideo = YES;
    
    UIButton *takePhotoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:takePhotoBtn];
    takePhotoBtn.frame = CGRectMake(20, 30, 100, 50);
    takePhotoBtn.backgroundColor = [UIColor purpleColor];
    [takePhotoBtn setTitle:@"拍照" forState:UIControlStateNormal];
    [takePhotoBtn addTarget:self action:@selector(takePhoto:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *recordVideoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:recordVideoBtn];
    recordVideoBtn.frame = CGRectMake(200, 30, 100, 50);
    recordVideoBtn.backgroundColor = [UIColor purpleColor];
    [recordVideoBtn setTitle:@"录制视频p" forState:UIControlStateNormal];
    [recordVideoBtn addTarget:self action:@selector(recordVideo:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *recVideoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:recVideoBtn];
    recVideoBtn.frame = CGRectMake(20, 100, 100, 50);
    recVideoBtn.backgroundColor = [UIColor purpleColor];
    [recVideoBtn setTitle:@"av录制视频" forState:UIControlStateNormal];
    [recVideoBtn addTarget:self action:@selector(avRecordVideo:) forControlEvents:UIControlEventTouchUpInside];
    
    _photo = [[UIImageView alloc] initWithFrame:CGRectMake(50, 300, 200, 200)];
    [self.view addSubview:_photo];
    _photo.layer.borderWidth = 1;
    
    
}

//  拍照
- (void)takePhoto:(id)sender {
    
}

- (void)avRecordVideo:(id)sender {
    avRecordVideoController *avController = [[avRecordVideoController alloc] init];
    [self presentViewController:avController animated:YES completion:nil];
}

//  UIImagePickerController 录制视频
- (void)recordVideo:(id)sender {
    _imagePicker = [[UIImagePickerController alloc] init];
    _imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;  //  设为摄像头
    _imagePicker.cameraDevice = UIImagePickerControllerCameraDeviceRear;    //  使用后置摄像头
    if (self.isVideo) {
        _imagePicker.mediaTypes = @[(NSString *)kUTTypeMovie];
        _imagePicker.videoQuality = UIImagePickerControllerQualityTypeIFrame1280x720;
        _imagePicker.cameraFlashMode = UIImagePickerControllerCameraCaptureModeVideo;   //  设置摄像头模式(拍照, 录制视频)
    } else {
        _imagePicker.cameraFlashMode = UIImagePickerControllerCameraCaptureModePhoto;
    }
    _imagePicker.allowsEditing = YES;   //  允许编辑
    _imagePicker.delegate = self;
    [_imagePicker startVideoCapture];
    
    [self presentViewController:_imagePicker animated:YES completion:nil];
    
}

#pragma mark    - UIImagePickerController delegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    if ([mediaType isEqualToString:(NSString *)kUTTypeImage]) { //  如果是拍照
        UIImage *image;
        //  如果允许编辑则获取编辑后的图片, 否则获取原图
        if (self.imagePicker.allowsEditing) {
            image = [info objectForKey:UIImagePickerControllerEditedImage];
        } else {
            image = [info objectForKey:UIImagePickerControllerOriginalImage];
        }
        
        [_photo setImage:image];
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);   //  保存到相册
        
    } else if ([mediaType isEqualToString:(NSString *)kUTTypeMovie]) {
        NSLog(@"录制视频!");
        NSURL *url = [info objectForKey:UIImagePickerControllerMediaURL];   //  视频路径
        NSString *urlStr = [url path];
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(urlStr)) {
            //  保存视频到相册, 也可以使用ALAssetsLibrary来保存
            UISaveVideoAtPathToSavedPhotosAlbum(urlStr, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
        }
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
    
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    NSLog(@"取消~");
}

#pragma mark    - 私有方法
- (UIImagePickerController *)imagePicker {
    
    if (!_imagePicker) {
        _imagePicker = [[UIImagePickerController alloc] init];
        _imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;  //  设为摄像头
        _imagePicker.cameraDevice = UIImagePickerControllerCameraDeviceRear;    //  使用后置摄像头
        if (self.isVideo) {
            _imagePicker.mediaTypes = @[(NSString *)kUTTypeMovie];
            _imagePicker.videoQuality = UIImagePickerControllerQualityTypeIFrame1280x720;
            _imagePicker.cameraFlashMode = UIImagePickerControllerCameraCaptureModeVideo;   //  设置摄像头模式(拍照, 录制视频)
        } else {
            _imagePicker.cameraFlashMode = UIImagePickerControllerCameraCaptureModePhoto;
        }
        _imagePicker.allowsEditing = YES;   //  允许编辑
        _imagePicker.delegate = self;
    }
    return _imagePicker;
}

//  视频保存后的回调
- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if (error) {
        NSLog(@"保存视频发送错误, 错误信息: %@", error.localizedDescription);
    } else {
        NSLog(@"视频录制成功");
        //  录制完之后自动播放
        NSURL *url = [NSURL fileURLWithPath:videoPath];
        _player = [AVPlayer playerWithURL:url];
        AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
//        playerLayer.bounds = self.photo.bounds;
        
        [self.photo.layer addSublayer:playerLayer];
        playerLayer.frame = CGRectMake(0, 0, 100, 200);
        [_player play];
        
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
