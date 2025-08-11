import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:jumping_game/data_stream/video_stream_capture.dart';
import 'package:jumping_game/features/command_factory.dart';
import 'package:jumping_game/features/base_command.dart';
import 'dart:html' as html; 
import 'dart:async';
import 'package:jumping_game/unity/simple_parameters.dart'; 


class UnityWebViewPage extends StatefulWidget {
  const UnityWebViewPage({super.key});

  @override
  State<UnityWebViewPage> createState() => _UnityWebViewPageState();
}

class _UnityWebViewPageState extends State<UnityWebViewPage> {
  final JumpRopeReadyCommand _jumpRopeReadyCommand = CommandFactory.jumpRopeReadyCommand;
  html.IFrameElement? _iframe;
  Timer? _timer;
  html.CanvasElement? _cameraCanvas;
  bool _cameraCanvasInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachUnity());
    _startCamera();
    //获取web中的数据
    html.window.onMessage.listen((html.MessageEvent event) {
      try {
        final raw = event.data;
        if (raw is String) {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          
          hasPerson1   = data['hasPerson1'] as bool;
          isPrepared1  = data['isPrepared1'] as bool;
          jumpCount1   = data['jumpCount1'] as int;
          hasPerson2   = data['hasPerson2'] as bool;
          isPrepared2  = data['isPrepared2'] as bool;
          jumpCount2   = data['jumpCount2'] as int;
          gameStarting = data['gameStarting'] as bool;
          gameEnded    = data['gameEnded'] as bool;

          // print('✅ 接收到来自 JS 的数据');
        } else {
          // print('⚠️ 非字符串数据：${event.data}');
        }
      } catch (e) {
        // print('❌ 解析失败: $e');
      }
    });
  }

  void _attachUnity() {
    
    // 创建Unity iframe
    _iframe = html.IFrameElement()
      ..id = 'unity-iframe'
      ..style.position = 'absolute'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..style.backgroundColor = 'transparent'
      ..style.zIndex = '3' // Unity在顶层
      ..src = '/web/unity-content/index.html';
    
    // 添加到DOM
    html.document.body?.append(_iframe!);

    _iframe!.onLoad.listen((_) {
      // 在这里启动定时器，确保Unity实例已经加载完成
      print('Unity iframe 加载完成');



      _startTimer();
    });
  }

  void _startCamera() {
    try {
      if (!_jumpRopeReadyCommand.isAlive()) {
        _jumpRopeReadyCommand.beginCmd();
      } else {
        _jumpRopeReadyCommand.endCmd();
        _jumpRopeReadyCommand.beginCmd();
      }
    } catch (e) {
      print('Error occurred when starting the camera command: $e');
    }
  }

  void _startTimer() {
  // 1) 20 ms 玩家数据循环（立即启动）
  _timer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
    final playerData = {
      'hasPerson1': hasPerson1,
      'isPrepared1': isPrepared1,
      'jumpCount1': jumpCount1,
      'hasPerson2': hasPerson2,
      'isPrepared2': isPrepared2,
      'jumpCount2': jumpCount2,
      'gameStarting': gameStarting,
      'gameEnded': gameEnded,
    };
    final playerJson = jsonEncode(playerData);
    final iframe = html.document.getElementById('unity-iframe') as html.IFrameElement?;
    if (iframe != null && iframe.contentWindow != null) {
      iframe.contentWindow!.postMessage(playerJson, '*');
      // print('定时器发送玩家数据: $playerJson');
    }
    _displayCurrentFrame();
  });

  // 2) 2 秒后一次性发送配置参数
  Timer(const Duration(seconds: 1), () {
    final configData = {
      'box1PosX': box1PosX,
      'box1PosY': box1PosY,
      'box1Width': box1Width,
      'box1Height': box1Height,

      'box2PosX': box2PosX,
      'box2PosY': box2PosY,
      'box2Width': box2Width,
      'box2Height': box2Height,

      'playerAnimationDuration': playerAnimationDuration,
      'gameAnimationDuration': gameAnimationDuration,

      'gameplayDuration': gameplayDuration,
      'bufferDuration': bufferDuration,
      'settlementCountdown': settlementCountdown,
    };
    final configJson = jsonEncode(configData);
    final iframe = html.document.getElementById('unity-iframe') as html.IFrameElement?;
    if (iframe != null && iframe.contentWindow != null) {
      iframe.contentWindow!.postMessage(configJson, '*');
      print('延迟5秒后发送配置参数: $configJson');
    }
  });
}

 void _displayCurrentFrame() {
    final VideoFrameData? frameData = getCurrentFrameImageData();
    if (frameData == null) return;

    // 确保canvas元素已创建
    _ensureCanvasInitialized(frameData.width, frameData.height);
    
    final ctx = _cameraCanvas!.context2D;
    ctx.clearRect(0, 0, _cameraCanvas!.width!, _cameraCanvas!.height!);

    
    // 直接在Canvas上绘制图像数据
    final imageData = html.ImageData(
      frameData.bytes.buffer.asUint8ClampedList(),
      frameData.width,
      frameData.height,
    );
    ctx.putImageData(imageData, 0, 0);
  }

  void _ensureCanvasInitialized(int width, int height) {
    if (_cameraCanvas == null) {
      _cameraCanvas = html.CanvasElement(width: width, height: height)
        ..id = 'cameraCanvas'
        ..style.border = '1px solid black'
        ..style.position = 'absolute'
        ..style.top = '50%'
        ..style.left = '50%'
        ..style.transform = 'translate(-50%, -50%)' // 居中显示
        ..style.borderRadius = '8px' // 添加圆角
        ..style.boxShadow = '0 4px 12px rgba(0,0,0,0.15)' // 添加阴影
        ..style.zIndex = '1'; // 确保canvas在Unity iframe下方
      
      html.document.body?.insertBefore(_cameraCanvas!, _iframe);
    } else if (_cameraCanvas!.width != width || _cameraCanvas!.height != height) {
      // 如果尺寸改变则调整canvas
      _cameraCanvas!.width = width;
      _cameraCanvas!.height = height;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Unity in Flutter'),
      ),
      body: Container(
        color: Colors.white,
        constraints: const BoxConstraints.expand(),
        child: Stack(
        children: [
          // 使用HtmlElementView来包装DOM元素
          Positioned.fill(
            child: IgnorePointer(
              child: _cameraCanvas != null
                  ? HtmlElementView(viewType: 'cameraCanvas')
                  : Container(),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: _iframe != null
                  ? HtmlElementView(viewType: 'unity-iframe')
                  : Container(),
            ),
          ),
        ],
      ),
      ),
    );
  }

  @override
  void dispose() {
    // 移除Unity iframe
    _iframe?.remove();
    
    // 停止摄像头采集
    if (_jumpRopeReadyCommand.isAlive()) {
      _jumpRopeReadyCommand.endCmd();
    }
    
    // 停止定时器
    _timer?.cancel();

    _cameraCanvas?.remove();

    super.dispose();
  }
}