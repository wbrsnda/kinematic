// ignore: use_string_in_part_of_directives
/// **Author**: wwyang
/// **Date**: 2025.5.7
/// **Copyright**: Multimedia Lab, Zhejiang Gongshang University
/// **Version**: 1.0
///
/// This program is free software: you can redistribute it and/or modify
/// it under the terms of the GNU General Public License as published by
/// the Free Software Foundation, either version 3 of the License, or
/// (at your option) any later version.
///
/// This program is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
/// GNU General Public License for more details.
///
/// You should have received a copy of the GNU General Public License
/// along with this program. If not, see <http://www.gnu.org/licenses/>.
part of command_lib;

/// ## JumpRopeReadyCommand

/// ### Instanceclass of the command
///
/// This class is used for processing operations ready for jumping rope.   
/// 
/// This command performs the most of operatoins in a separate thread. The process logic of this command is: 
/// (1) open data stream from the default camera; 
/// (2) detect human bboxs and their poses; 
/// (3) handling the interaction through detected poses;
/// (4) if ready, notify the app to go to the jump_rope_runing session.
/// 
/// {@macro command_example_usage}
class JumpRopeReadyCommand extends BaseCommand {
  // Data: current frame image for rendering; heaps for each processing sub-section; frame data in heaps - id, image, bboxs, poses; ready status 

  /// Video capture stream from the default camera
  VideoStreamCaptureFromCamera? _captureCamera; 

  /// Web worker for a separate thread -- Non js object
  Worker? _myWorker;

  /// Web worker is waiting for data
  bool _isWorkerWaitForData = false;

  /// Timestamp of the video frame that was sent to the Web worker last time
  int _lastSentFrameId = 0;

  void Function(int timestamp, VideoFrameData frameData)? frameDataCallback;

  /// {@macro begin_command_implement}
  @override
  Future<void> _beginCmdImplement() async{
    // 1. Initialize the data repository and others
    RepositoryFactory.jumpRopeReadyRepository.freeRepository();

    _isWorkerWaitForData = false; // The Worker notify that it's ready for receiving data
    _lastSentFrameId = 0;

    _captureCamera = null;
    _myWorker = null;

    // 2. Open the video stream from the default camera
    _captureCamera = VideoStreamCaptureFromCamera(width: 800, height: 600);
    bool isStart = false;
    try {
      isStart = await _captureCamera!.start((
        int timestamp,
        VideoFrameData frameData,
      ) { 
        // Call back function when capturing a video frame 

        var dataRepository = RepositoryFactory.jumpRopeReadyRepository;

        dataRepository.curFrameID = timestamp;
        dataRepository.curframeData = frameData; 


        if(_isWorkerWaitForData){ // send current data to the worker for processing
          if(_sendDataToWebWorker()) _isWorkerWaitForData = false;
        }

       // 更新全局变量 currentFrameImageData
        updateCurrentFrameImageData(frameData);

      }, fps: 30);
    } catch (e) {
      print('Errors occur when opening the camera video stream');
    }

    if(!isStart) return;

    // 3. Create a new thread to process the data
    _runProcessSession();

    // 4. Create a timer to send the data to render
    // TODO...
    _createRenderTimer();

  }

  /// Create a web worker to process the captured video data
  void _runProcessSession(){

    // 1. Create a new Web Worker
    _myWorker = Worker('workers/jump_rope_ready_worker_session.dart.js');

    // 2. Listen for messages from the Web Worker
    _myWorker!.onMessage.listen((MessageEvent event) {
      final data = event.data; // Maybe Js map, list, or string (or basic data type) 

      if(data is Map){
        if(data['type'] == 'wait_for_data'){ // web worker is waiting for a new data to process
          _isWorkerWaitForData = true;

          if(_sendDataToWebWorker()) _isWorkerWaitForData = false;
        }
        else{ // The returned data after processing by Web Worker
          
          if(data['type'] == 'frame'){
            // Put it into the repository
            _getDataFromWebWorker(data);

            // The following is for test. ... Please delete them.

            //int diffInMilliseconds = DateTime.now().difference(data['time'] as DateTime).inMilliseconds;
            //print('Main receive a worker_frame_data after ${diffInMilliseconds} ms');

            // Draw the current frame data
            final int frameId = data['frameId'];
            final int width = data['width'];
            final int height = data['height'];
            final pixels = Uint8List.view(data['buffer']);
            ImageData imageData = ImageData(width, height);

            // 将Uint8List的数据复制到ImageData对象的数据缓冲区中
            // imageData.data是一个Uint8ClampedList类型，它是直接映射到底层的CanvasPixelArray的
            // 因此我们可以使用.setRange方法来复制数据
            // 获取 canvas 元素
            CanvasElement canvas = querySelector('#imageCanvas') as CanvasElement;
            CanvasRenderingContext2D context =
                canvas.getContext('2d') as CanvasRenderingContext2D;
            imageData.data.setRange(0, pixels.length, pixels);

            context.putImageData(imageData, 0, 0);


          }

        }
      }

    });

    // 3. Send message to the Web Worker to notify it to initialize 
    _myWorker!.postMessage({'type': 'initialize', 'time': DateTime.now()});
  }

  /// Send data to the Web Worker
  /// 
  /// Output: if a new data is sent to web worker return true; otherwise false 
  bool _sendDataToWebWorker(){
    var dataRepository = RepositoryFactory.jumpRopeReadyRepository;

    if(dataRepository.curFrameID > _lastSentFrameId && dataRepository.curframeData != null){
      // Send current video frame to the Worker 
      Uint8List copyImage = Uint8List.fromList(dataRepository.curframeData!.bytes); 
      final data = {
        'type': 'frame',
        'buffer': copyImage.buffer,  // we transfer the copy image data to the worker, so the repository still hold the original image. 
        'width': dataRepository.curframeData!.width,
        'height': dataRepository.curframeData!.height,
        'frameId': dataRepository.curFrameID,
        'time': DateTime.now(),
      };

      // transfer copy
      _myWorker!.postMessage(data, [copyImage.buffer]);

      _lastSentFrameId = RepositoryFactory.jumpRopeReadyRepository.curFrameID;

      return true;
    }

    return false;
  }

  /// Get a data from the Web Worker
  /// 
  /// Here, we put the [data], which is returned by Worker after processing, into repository   
  void _getDataFromWebWorker(dynamic data){
     // TODO....
     // 
  }

  /// Create a timer for rendering the data at a fixed frame rate
  /// 
  /// **Note:** In this feature, we need to display the video frames and the intermediate output data,
  /// so we create a timer to do the rendering at a fixed frame rate
  void _createRenderTimer(){
     // Actually, at each time step, we send the current new data to the WebGL who is reponsible for the rendering 
     // TODO...  
  }

  /// {@macro end_command_implement}
  @override
  Future<void> _endCmdImplement() async{
    // Clear the Rendering timer
    // .. TODO

    // Stop the Web Worker
    if (_myWorker != null) {
      _myWorker!.terminate();
      _myWorker = null; // 释放引用
    }

    // Stop the camera video stream
    if(_captureCamera != null){
      await _captureCamera!.stop();
      _captureCamera = null;
    }
   
  }
}


