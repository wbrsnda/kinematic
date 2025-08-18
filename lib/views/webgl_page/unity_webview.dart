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
  Timer? _playerDataTimer; // 玩家数据计时器
  html.CanvasElement? _cameraCanvas;
  bool _cameraCanvasInitialized = false;
  
  // 状态变量
  bool _unityReady = false; // Unity是否已初始化完成
  bool _configSent = false; // 配置是否已发送
  final List<String> _messageQueue = []; // 消息队列
  late final String _configJson; // 预先生成的配置JSON

  @override
  void initState() {
    super.initState();
    
    // 预先生成配置JSON
    final configData = {
      'box1PosX': repository.box1PosX,
      'box1PosY': repository.box1PosY,
      'box1Width': repository.box1Width,
      'box1Height': repository.box1Height,
      'box2PosX': repository.box2PosX,
      'box2PosY': repository.box2PosY,
      'box2Width': repository.box2Width,
      'box2Height': repository.box2Height,
      'playerAnimationDuration': repository.playerAnimationDuration,
      'gameAnimationDuration': repository.gameAnimationDuration,
      'gameplayDuration': repository.gameplayDuration,
      'bufferDuration': repository.bufferDuration,
      'settlementCountdown': repository.settlementCountdown,
    };
    _configJson = jsonEncode(configData);
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachUnity());
    _startCamera();
    
    // 添加Unity就绪监听器
    html.window.addEventListener('message', _handleUnityMessage);
    
    // 获取web中的数据
    html.window.onMessage.listen((html.MessageEvent event) {
      try {
        final raw = event.data;
        if (raw is String) {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          
          repository.hasPerson1    = data['hasPerson1'] as bool;
          repository.isPrepared1   = data['isPrepared1'] as bool;
          repository.jumpCount1    = data['jumpCount1'] as int;
          repository.hasPerson2    = data['hasPerson2'] as bool;
          repository.isPrepared2   = data['isPrepared2'] as bool;
          repository.jumpCount2    = data['jumpCount2'] as int;
          repository.gameStarting  = data['gameStarting'] as bool;
          repository.gameEnded     = data['gameEnded'] as bool;

          // print('✅ 接收到来自 JS 的数据');
        } else {
          // print('⚠️ 非字符串数据：${event.data}');
        }
      } catch (e) {
        // print('❌ 解析失败: $e');
      }
    });
  }

  // 处理Unity消息
  void _handleUnityMessage(html.Event event) {
    if (event is! html.MessageEvent) return;
    final messageEvent = event as html.MessageEvent;
    
    if (messageEvent.data == 'unity-ready') {
      setState(() {
        _unityReady = true;
      });
      print("收到Unity就绪消息");
      
      // 发送配置参数
      _sendConfiguration();
      
      // 启动玩家数据定时器
      _startPlayerDataTimer();
      
      // 发送队列中的消息
      _flushMessageQueue();
    }
  }

  // 发送队列中的消息
  void _flushMessageQueue() {
    if (_iframe == null || _iframe!.contentWindow == null) return;
    
    for (final message in _messageQueue) {
      _iframe!.contentWindow!.postMessage(message, '*');
      print("发送队列消息: $message");
    }
    _messageQueue.clear();
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
      print('Unity iframe 加载完成');
      // 不再在此启动定时器，等待Unity就绪消息
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

  // 启动玩家数据定时器
  void _startPlayerDataTimer() {
    _playerDataTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      final playerData = {
        'hasPerson1': repository.hasPerson1,
        'isPrepared1': repository.isPrepared1,
        'jumpCount1': repository.jumpCount1,
        'hasPerson2': repository.hasPerson2,
        'isPrepared2': repository.isPrepared2,
        'jumpCount2': repository.jumpCount2,
        'gameStarting': repository.gameStarting,
        'gameEnded': repository.gameEnded,
      };
      final playerJson = jsonEncode(playerData);
      
      // 发送消息（如果Unity未准备好则加入队列）
      _postMessage(playerJson);
      
      _displayCurrentFrame();
    });
  }

  // 发送配置参数
  void _sendConfiguration() {
    if (_configSent) {
      print('配置参数已发送过，跳过');
      return;
    }
    
    if (_iframe == null || _iframe!.contentWindow == null) {
      print('Unity iframe 未准备好，无法发送配置');
      return;
    }
    
    try {
      _iframe!.contentWindow!.postMessage(_configJson, '*');
      _configSent = true;
      print('配置参数发送成功');
    } catch (e) {
      print('配置参数发送失败: $e');
    }
  }

  // 发送消息（处理Unity就绪状态）
  void _postMessage(String message) {
    if (_iframe == null || _iframe!.contentWindow == null) return;
    
    if (_unityReady) {
      _iframe!.contentWindow!.postMessage(message, '*');
      // print('发送玩家数据: $message');
    } else {
      // 如果Unity未准备好，将消息加入队列
      _messageQueue.add(message);
      // print('玩家数据加入队列: $message');
    }
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
    _playerDataTimer?.cancel();

    _cameraCanvas?.remove();
    
    // 移除消息监听器
    html.window.removeEventListener('message', _handleUnityMessage);

    super.dispose();
  }
}