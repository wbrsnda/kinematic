library repository_lib;

import 'base_repository.dart';
import 'package:jumping_game/data_stream/video_stream_capture.dart' as video_capture;

class JumpRopeRepository extends BaseRepository {
  JumpRopeRepository._internal();
  static final JumpRopeRepository _instance = JumpRopeRepository._internal();
  factory JumpRopeRepository() => _instance;

  // 游戏状态参数
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
  int gameAnimationDuration = 8;  // 游戏进度条动画时长(秒)

  // 阶段全局参数
  int gameplayDuration = 60; // 游戏阶段时长(秒)
  int bufferDuration = 5;  // 缓冲阶段时长(秒)
  int settlementCountdown = 10; // 结算倒计时(秒)

  /// video image of the current frame
  video_capture.VideoFrameData? curframeData;

  /// timestamp of the current frame
  int curFrameID = 0;

  /// information used for the 'ready' sub-feature
  final JumpRopeReadyInformation _jumpRopeReadyInformation = JumpRopeReadyInformation();

  /// Get the 'ready' information
  JumpRopeReadyInformation get jumpRopeReadyInformation => _jumpRopeReadyInformation;

  /// 将 Unity 框参数转换为归一化 ROI 参数
  Map<String, double> getNormalizedRoi(int posX, int posY, int width, int height) {
    // Unity 的总屏幕尺寸为 800x600
    const unityScreenWidth = 800.0;
    const unityScreenHeight = 600.0;
    
    // Unity 坐标系中心点是 (0,0)，我们需要转换成左上角为(0,0)
    // 转换 x 坐标: 从 [-400, 400] 到 [0, 800]
    final screenX = posX + unityScreenWidth / 2;
    final screenY = unityScreenHeight / 2 - posY;

    final boxLeft = screenX - width / 2;
    final boxTop = screenY - height / 2;
    final boxRight = screenX + width / 2;
    final boxBottom = screenY + height / 2;

    final normalizedLeft = boxLeft / unityScreenWidth;
    final normalizedTop = boxTop / unityScreenHeight;
    final normalizedRight = boxRight / unityScreenWidth;
    final normalizedBottom = boxBottom / unityScreenHeight;
    
    return {
      'left': normalizedLeft,
      'top': normalizedTop,
      'right': normalizedRight,
      'bottom': normalizedBottom,
    };
  }

  /// {@macro free_repository}
  @override
  Future<void> freeRepository() async {
    // 重置 simple_parameters 中的参数
    hasPerson1 = false;
    isPrepared1 = false;
    jumpCount1 = 0;
    hasPerson2 = false;
    isPrepared2 = false;
    jumpCount2 = 0;
    gameStarting = false;
    gameEnded = false;

    box1PosX = -200;
    box1PosY = 0;
    box1Width = 320;
    box1Height = 480;

    box2PosX = 200;
    box2PosY = 0;
    box2Width = 320;
    box2Height = 480;

    playerAnimationDuration = 3;
    gameAnimationDuration = 5;

    gameplayDuration = 10;
    bufferDuration = 5;
    settlementCountdown = 5;

    // 重置原有参数
    curframeData = null;
    curFrameID = 0;

    _jumpRopeReadyInformation.hasBodyInLeftBox = false;
    _jumpRopeReadyInformation.bodyDurationInLeftBox = 0;
    _jumpRopeReadyInformation.hasBodyInRightBox = false;
    _jumpRopeReadyInformation.bodyDurationInRightBox = 0;
  }

  
}

/// Represents information for the 'ready' sub-feature
class JumpRopeReadyInformation {
  bool hasBodyInLeftBox = false; // whether a body in the left box
  int bodyDurationInLeftBox = 0; // duration time of current body staying in the left box

  bool hasBodyInRightBox = false; // whether a body in the right box
  int bodyDurationInRightBox = 0; // duration time of current body staying in the right box

  bool isReady = false; // whether the jumping is ready

  /// **Note:** you can modify it
  /// according to your need
  int bodyDurationTimeMax = 60; // seconds: beyond this time, the jumping is automatically ready
}