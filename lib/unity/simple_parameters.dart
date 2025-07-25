// simple_parameters.dart

// 全局参数
import 'package:jumping_game/data_stream/video_stream_capture.dart';
import 'dart:async';

// 原有全局参数
bool hasPerson1 = true;
bool isPrepared1 = false;
int jumpCount1 = 95;
bool hasPerson2 = false;
bool isPrepared2 = false;
int jumpCount2 = 88;
bool gameStarting = false;
bool gameEnded = false;

// 框1布局参数
int box1PosX = -200;
int box1PosY = 0;
int box1Width = 320;
int box1Height = 480;

// 框2布局参数
int box2PosX = 200;
int box2PosY = 0;
int box2Width = 320;
int box2Height = 480;

// 动画时长参数
int playerAnimationDuration = 3; // 玩家进度条动画时长(秒)
int gameAnimationDuration = 10;   // 游戏进度条动画时长(秒)

// 阶段全局参数
int gameplayDuration = 60; // 游戏阶段时长(秒)
int bufferDuration = 5;    // 缓冲阶段时长(秒)
int settlementCountdown = 20; // 结算倒计时(秒)

// 图像数据
VideoFrameData? currentFrameImageData;
// 帧计数器
int frameId = 0;

// ========== 原有参数更新方法 ==========
void updateHasPerson1(bool newValue) {
  hasPerson1 = newValue;
}

void updateIsPrepared1(bool newValue) {
  isPrepared1 = newValue;
}

void updateJumpCount1(int newValue) {
  jumpCount1 = newValue;
}

void updateHasPerson2(bool newValue) {
  hasPerson2 = newValue;
}

void updateIsPrepared2(bool newValue) {
  isPrepared2 = newValue;
}

void updateJumpCount2(int newValue) {
  jumpCount2 = newValue;
}

void updateGameStarting(bool newValue) {
  gameStarting = newValue;
}

void updateGameEnded(bool newValue) {
  gameEnded = newValue;
}

// 框1位置更新
void updateBox1Position(int posX, int posY) {
  box1PosX = posX;
  box1PosY = posY;
}

// 框1尺寸更新
void updateBox1Size(int width, int height) {
  box1Width = width;
  box1Height = height;
}

// 框2位置更新
void updateBox2Position(int posX, int posY) {
  box2PosX = posX;
  box2PosY = posY;
}

// 框2尺寸更新
void updateBox2Size(int width, int height) {
  box2Width = width;
  box2Height = height;
}

// 动画时长更新
void updatePlayerAnimationDuration(int duration) {
  playerAnimationDuration = duration;
}

void updateGameAnimationDuration(int duration) {
  gameAnimationDuration = duration;
}

// 各阶段更新
void updateGameplayDuration(int duration) {
  gameplayDuration = duration;
}

void updateBufferDuration(int duration) {
  bufferDuration = duration;
}

void updateSettlementCountdown(int duration) {
  settlementCountdown = duration;
}

// 图像数据更新
void updateCurrentFrameImageData(VideoFrameData newImageData) {
  currentFrameImageData = newImageData;
  frameId++;
}

VideoFrameData? getCurrentFrameImageData() {
  return currentFrameImageData;
}

// 获取当前帧ID
int getCurrentFrameId() {
  return frameId;
}



// 测试方法
void delayedUpdateParameters() {
  Timer(Duration(seconds: 5), () {
    print("5秒后更新玩家1状态");
    updateIsPrepared1(true);
    
  });
}

// 新增：15秒后更新游戏开始状态
void delayedUpdateGameStart() {
  Timer(Duration(seconds: 15), () {
    print("15秒后更新游戏开始状态");
    updateGameStarting(true);
    
  });
}
