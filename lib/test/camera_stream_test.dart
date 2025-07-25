
import 'dart:html';

import 'package:jumping_game/data_stream/video_stream_capture.dart';

VideoFrameData? curFrameData;

void test_camera_stream() async{
  VideoStreamCaptureFromCamera captureCamera = VideoStreamCaptureFromCamera(width: 800, height: 600);

  bool isStart = false;
  try{
    isStart = await captureCamera.start((int timestamp, VideoFrameData frameData) {
      //print('Obtained frame: $timestamp');
      curFrameData = frameData;

      //if(timestamp == 200) captureCamera.stop();

    }, fps: 100);
  }catch(e){
    print('Errors occur when opening the camera video stream');
  }

  if(!isStart){
    print('Camera video stream cannot run');
    return;
  }
  else{
    print('Camera video stream is running. fps:${captureCamera.fps}');
  }

  // 获取 canvas 元素
  CanvasElement canvas = querySelector('#imageCanvas') as CanvasElement;
  CanvasRenderingContext2D context = canvas.getContext('2d') as CanvasRenderingContext2D;

  drawCurFrame(context);
}

void drawCurFrame(CanvasRenderingContext2D context){
  if(curFrameData != null){
    // Draw the current frame data
    ImageData imageData = ImageData(curFrameData!.width, curFrameData!.height);

  // 将Uint8List的数据复制到ImageData对象的数据缓冲区中
  // imageData.data是一个Uint8ClampedList类型，它是直接映射到底层的CanvasPixelArray的
  // 因此我们可以使用.setRange方法来复制数据
    imageData.data.setRange(0, curFrameData!.bytes.length, curFrameData!.bytes);
    context.putImageData(imageData, 0, 0);
  }

  window.requestAnimationFrame((_) => drawCurFrame(context)); // refresh the screen
}



