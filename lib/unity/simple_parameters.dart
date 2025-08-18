// simple_parameters.dart

import 'package:jumping_game/data_stream/video_stream_capture.dart';
import 'package:jumping_game/scene_repository/jump_rope_repository.dart'; 
import 'dart:async';

final repository = JumpRopeRepository();


void updateHasPerson1(bool newValue) {
  repository.hasPerson1 = newValue;
}

void updateIsPrepared1(bool newValue) {
  repository.isPrepared1 = newValue;
}

void updateJumpCount1(int newValue) {
  repository.jumpCount1 = newValue;
}

void updateHasPerson2(bool newValue) {
  repository.hasPerson2 = newValue;
}

void updateIsPrepared2(bool newValue) {
  repository.isPrepared2 = newValue;
}

void updateJumpCount2(int newValue) {
  repository.jumpCount2 = newValue;
}

void updateGameStarting(bool newValue) {
  repository.gameStarting = newValue;
}

void updateGameEnded(bool newValue) {
  repository.gameEnded = newValue;
}

// 框1位置更新
void updateBox1Position(int posX, int posY) {
  repository.box1PosX = posX;
  repository.box1PosY = posY;
}

// 框1尺寸更新
void updateBox1Size(int width, int height) {
  repository.box1Width = width;
  repository.box1Height = height;
}

// 框2位置更新
void updateBox2Position(int posX, int posY) {
  repository.box2PosX = posX;
  repository.box2PosY = posY;
}

// 框2尺寸更新
void updateBox2Size(int width, int height) {
  repository.box2Width = width;
  repository.box2Height = height;
}

// 动画时长更新
void updatePlayerAnimationDuration(int duration) {
  repository.playerAnimationDuration = duration;
}

void updateGameAnimationDuration(int duration) {
  repository.gameAnimationDuration = duration;
}

// 各阶段更新
void updateGameplayDuration(int duration) {
  repository.gameplayDuration = duration;
}

void updateBufferDuration(int duration) {
  repository.bufferDuration = duration;
}

void updateSettlementCountdown(int duration) {
  repository.settlementCountdown = duration;
}

// 图像数据更新
void updateCurrentFrameImageData(VideoFrameData newImageData) {
  repository.curframeData = newImageData;
  repository.curFrameID++;
}

VideoFrameData? getCurrentFrameImageData() {
  return repository.curframeData;
}

// 获取当前帧ID
int getCurrentFrameId() {
  return repository.curFrameID;
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