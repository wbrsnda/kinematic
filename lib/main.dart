import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:js/js_util.dart' as js_util;
import 'dart:async';
import 'package:jumping_game/features/command_factory.dart';
import 'package:jumping_game/scene_repository/repository_factory.dart';
import 'package:jumping_game/test/command_test.dart';
import 'dart:convert';

import 'package:jumping_game/views/webgl_page/unity_webview.dart'; 
import 'package:jumping_game/unity/simple_parameters.dart' as params;



bool hasPerson1 = false;
bool hasPerson2 = false;

bool isPrepared1 = false;
bool isPrepared2 = false;

bool gameStarting = false;
bool gameEnded = true;

int jumpCount1 = 0;
int jumpCount2 = 0;

void main() async {
  runApp(const MyApp());
  // 页面关闭时清理资源
  html.window.onBeforeUnload.listen((event) {
    print('Cleaning up for exiting...');
    doCleanup();
    event.preventDefault();
  });

  // 启动命令逻辑
  test_jump_rope_command();

  // 在 Timer 循环和视频/Canvas 逻辑之前，获取并发送游戏配置 ---
  _sendGameConfig(); 

  // 每 100ms 试一次，直到拿到元素
  Timer.periodic(Duration(milliseconds: 100), (timer) {
    final video = html.document.querySelector('video') as html.VideoElement?;
    final canvas = html.document.querySelector('#imageCanvas') as html.CanvasElement?;

    if (video != null && canvas != null) {
      timer.cancel(); // 找到元素后停止定时器

      // 确保视频元数据加载完成后再设置 canvas 尺寸并初始化 JS 估计器
      video.onLoadedMetadata.first.then((_) {
        canvas
          ..width = video.videoWidth
          ..height = video.videoHeight;

        js.context.callMethod('initPoseEstimator', [video, canvas]);
        print('✅ 已找到 video 和 canvas，初始化 JS 完成');
        // 游戏配置已在此之前发送，这里无需重复发送
      }).catchError((e) {
        print('❌ 视频元数据加载失败或出错：$e');
      });

    } else {
      print('⚠️ 尚未找到 video 或 canvas，继续等待...');
    }
  });
}


// 封装发送游戏配置的逻辑
void _sendGameConfig() {
  print('⚙️ 准备发送游戏配置… (在 Canvas 初始化之前)');
  try {
    final configMap = {
      'playerAnimationDuration': params.playerAnimationDuration * 1000,
      'gameAnimationDuration':   params.gameAnimationDuration   * 1000,
      'gameplayDuration':        params.gameplayDuration        * 1000,
      'bufferDuration':          params.bufferDuration          * 1000,
      'settlementCountdown':     params.settlementCountdown     * 1000,
    };
    print('⚙️ configMap = $configMap');

    // <<<<<<< 关键修改: 将 Map 编码为 JSON 字符串
    final jsonString = jsonEncode(configMap);
    print('⚙️ 发送 JSON 字符串到 JavaScript：$jsonString');
    js.context.callMethod('updateGameConfig', [jsonString]);
    // >>>>>>>

    print('⚙️ 已发送游戏配置到 JavaScript (成功)');
  } catch (e) {
    print('❌ updateGameConfig 调用失败 (在 Canvas 初始化之前)：$e');
    print('DEBUG: params values - playerAnimationDuration: ${params.playerAnimationDuration}, gameAnimationDuration: ${params.gameAnimationDuration}, gameplayDuration: ${params.gameplayDuration}, bufferDuration: ${params.bufferDuration}, settlementCountdown: ${params.settlementCountdown}');
  }
}

Future<void> doCleanup() async {
  await CommandFactory.stopAllLiveCmd();
  await RepositoryFactory.freeAllRepository();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unity in Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const UnityWebViewPage(),
    );
  }
}
