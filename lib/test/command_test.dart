// import 'package:jumping_game/features/command_factory.dart';


// void test_jump_rope_command(){
//   // Get the handle of the command from the factory
//   var refCommand = CommandFactory.jumpRopeReadyCommand;

//   try{
//     if(!refCommand.isAlive()){
//       refCommand.beginCmd(); // start to run the command 
//     }
//     else{
//       refCommand.endCmd(); // stop the command
//     }     
//   }catch(e){
//     print('Error occurs when starting/stopping the command: $e');
//   }
// }

import 'dart:async';
import 'package:jumping_game/features/command_factory.dart';
import 'package:jumping_game/data_stream/video_stream_capture.dart';
import 'package:jumping_game/scene_repository/repository_factory.dart';

Timer? _cameraDebugTimer;

void test_jump_rope_command() {
  // Get the handle of the command from the factory
  var refCommand = CommandFactory.jumpRopeReadyCommand;

  try {
    if (!refCommand.isAlive()) {
      refCommand.beginCmd(); // Start to run the command

      // 开始一个定时器，每100ms打印当前帧信息
      _cameraDebugTimer = Timer.periodic(Duration(milliseconds: 100), (_) {
        final frame = RepositoryFactory.jumpRopeReadyRepository.curframeData;
        final frameId = RepositoryFactory.jumpRopeReadyRepository.curFrameID;
        if (frame != null) {
          // print('[Camera Input] FrameID: $frameId, Size: ${frame.width}x${frame.height}, Bytes: ${frame.bytes.length}');
        } else {
          print('[Camera Input] No frame available yet...');
        }
      });

    } else {
      refCommand.endCmd(); // Stop the command

      // 停止定时器
      if (_cameraDebugTimer != null) {
        _cameraDebugTimer!.cancel();
        _cameraDebugTimer = null;
      }

      print('[Camera Input] Command stopped. Timer cancelled.');
    }
  } catch (e) {
    print('Error occurs when starting/stopping the command: $e');
  }
}

