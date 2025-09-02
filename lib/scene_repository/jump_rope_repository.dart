library repository_lib;

import 'base_repository.dart';
import 'package:jumping_game/data_stream/video_stream_capture.dart' as video_capture;

class JumpRopeRepository extends BaseRepository {
  JumpRopeRepository._internal() {
    _initializeParameters();
  }

  static final JumpRopeRepository _instance = JumpRopeRepository._internal();
  //此处为初始化，修改参数在下方
  factory JumpRopeRepository() => _instance;
    bool hasPerson1 = false;
    bool isPrepared1 = false;
    int jumpCount1 = 0;
    bool hasPerson2 = false;
    bool isPrepared2 = false;
    int jumpCount2 = 0;
    bool gameStarting = false;
    bool gameEnded = false;

    String? username1;  // 左侧/玩家1
    String? username2;  // 右侧/玩家2
    String? userId1;    
    String? userId2;


    int box1PosX = 0;
    int box1PosY = 0;
    int box1Width = 0;
    int box1Height = 0;
    int box2PosX = 0;
    int box2PosY = 0;
    int box2Width = 0;
    int box2Height = 0;

    int playerAnimationDuration = 0;
    int gameAnimationDuration = 0;
    int gameplayDuration = 0;
    int bufferDuration = 0;
    int settlementCountdown = 0;

    video_capture.VideoFrameData? curframeData;
    int curFrameID = 0;

  final JumpRopeReadyInformation _jumpRopeReadyInformation = JumpRopeReadyInformation();

  JumpRopeReadyInformation get jumpRopeReadyInformation => _jumpRopeReadyInformation;

  //修改参数
  void _initializeParameters() {
    hasPerson1 = false;
    isPrepared1 = false;
    jumpCount1 = 0;
    hasPerson2 = false;
    isPrepared2 = false;
    jumpCount2 = 0;
    gameStarting = false;
    gameEnded = false;

    username1 = null;
    username2 = null;
    userId1   = null;
    userId2   = null;

    box1PosX = -200;
    box1PosY = 0;
    box1Width = 320;
    box1Height = 480;

    box2PosX = 200;
    box2PosY = 0;
    box2Width = 320;
    box2Height = 480;

    playerAnimationDuration = 3;
    gameAnimationDuration = 8;

    gameplayDuration = 60;
    bufferDuration = 3;
    settlementCountdown = 15;

    curframeData = null;
    curFrameID = 0;

    _jumpRopeReadyInformation.hasBodyInLeftBox = false;
    _jumpRopeReadyInformation.bodyDurationInLeftBox = 0;
    _jumpRopeReadyInformation.hasBodyInRightBox = false;
    _jumpRopeReadyInformation.bodyDurationInRightBox = 0;
  }

  /// Converts Unity box parameters into normalized ROI parameters (0.0 to 1.0).
  ///
  /// The Unity screen size is assumed to be 800x600 with the origin (0,0) at the center.
  Map<String, double> getNormalizedRoi(int posX, int posY, int width, int height) {
    const unityScreenWidth = 800.0;
    const unityScreenHeight = 600.0;
    
    // Convert Unity's center-based coordinates to top-left based coordinates.
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
    // Reset all parameters to their initial state by calling the private initializer.
    _initializeParameters();
  }
}

/// Represents information for the 'ready' sub-feature.
class JumpRopeReadyInformation {
  // Whether a body is detected in the left box.
  bool hasBodyInLeftBox = false;
  // The duration (in milliseconds) a body has stayed in the left box.
  int bodyDurationInLeftBox = 0;
  // Whether a body is detected in the right box.
  bool hasBodyInRightBox = false;
  // The duration (in milliseconds) a body has stayed in the right box.
  int bodyDurationInRightBox = 0;
  // Whether the jumping is ready.
  bool isReady = false;

  /// The time (in seconds) beyond which the jumping is automatically ready.
  /// You can modify this value as needed.
  int bodyDurationTimeMax = 60;
}