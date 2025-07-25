
// ignore: use_string_in_part_of_directives
/// **Author**: wwyang
/// **Date**: 2025.5.2
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
part of video_stream_capture_lib;

/// ## VideoSteramCaptureFromCamera
///
/// ### Instanceclass of the Video Data Stream Generator
///
/// This class is used for generating the data stream from a camera. The camera device is for web application
///
/// Example usage:
///
/// ```dart
/// // Create a camera data capturer with the frame size [800, 600]
/// VideoStreamCaptureFromCamera captureCamera = VideoStreamCaptureFromCamera(width: 800, height: 600);

/// bool isStart = false;
/// VideoFrameData curFrameData;
/// try{
///    // Begin to capture the camera data by 25 FPS 
///    isStart = await captureCamera.start((int timestamp, VideoFrameData frameData) {
///         // Obtain and process the per-frame data
///         curFrameData = frameData;
///    }, fps: 25);
///  }catch(e){
///    print('Errors occur when opening the camera video stream');
///  }
/// ```
class VideoStreamCaptureFromCamera extends VideoStreamCapture{
  /// Frame's size
  int _width = 800, _height = 600;

  /// A hidden video element linked to a default camera
  VideoElement? _videoElement;

  /// A hidden canvas context for obtaing data from a video element
  CanvasRenderingContext2D? _context;

  /// Variable to track the last captured time
  //DateTime? _lastCapturedTime;

  /// Constructor with the specified frame size
  VideoStreamCaptureFromCamera({int width = 800, int height = 600}) : _width = width, _height = height;

  /// {@macro start_implement}
  @override
  Future<bool> _startImplement() async{
    // 1. Check if a default camera exists
    bool hasCamera = await _checkCameraAvailability();
    
    if(!hasCamera) return false;

    // 2. Create a video object for the camera with the specified FPS
    try{
      // (1) Request access to the default camera
      _width = _width == 0 ? 800 : _width; 
      _height = _height == 0 ? 800 : _height; 

      Map<String, dynamic> constraints = {
        'video': {
          'width': {'ideal':  _width},    // Desired width
          'height': {'ideal': _height},    // Desired height
          'frameRate': {'ideal': _fps}, // Desired framerate
        },
      };
      MediaStream stream = await window.navigator.mediaDevices!.getUserMedia(constraints);

      // (2) Get the video track settings
      MediaStreamTrack track = stream.getVideoTracks()[0];
      Map<dynamic, dynamic> settings = track.getSettings();
      double actualFramerate = settings['frameRate'] ?? 0.0;

      if(actualFramerate.toInt() != _fps ){
        _fps = actualFramerate.toInt();
      }
      
      if(settings['width'] != _width){
        _width = settings['width']; 
      }
      if(settings['height'] != _height){
        _height = settings['height']; 
      }

      if(_fps == 0 || _width == 0 || _height == 0) return false;

      // (3) Create a hidden video element dynamically
      _videoElement = VideoElement()
        ..autoplay = true;

      // Set the playsinline attribute
      _videoElement!.setAttribute('playsinline', '');
      _videoElement!.style.display = 'none'; // Hide the video element

      // Append the video element to the body (hidden)
      document.body?.append(_videoElement!);

      // (4) Set the camera as the source of the video object
      _videoElement!.srcObject = stream;

      // (5) Wait for the video element to play and have dimensions
      await _videoElement!.onCanPlay.first;
      await Future.delayed(Duration(milliseconds: 100)); // Ensure dimensions are set
      
      assert(_videoElement!.videoWidth == _width);
      assert(_videoElement!.videoHeight == _height);
      
    }catch(e){
      return false;
    }

    // 3. Attach the video object to canvas for reading image stream from the camera
    // Create a hidden canvas element dynamically
    final canvasElement = CanvasElement(width: _width, height: _height);
    
    canvasElement.style.display = 'none'; // Hide the canvas element   
    _context = canvasElement.getContext('2d') as CanvasRenderingContext2D;

    return true;
  }

  /// {@macro stop_implement}
  @override
  Future<void> _stopImplement() async{
    // Release the camera resources
    _videoElement = null;
    _context = null;
  }

  /// {@macro read_current_data}
  @override
  Future<void> _readCurrentDataAsyn() async{
    if(_videoElement == null || _context == null) return;

    // if a new frame has been sent from the camera 
    // final now = DateTime.now();
    // bool isNewData = _lastCapturedTime == null || now.difference(_lastCapturedTime!).inMilliseconds > 15;
    // bool isNewData = _lastCapturedTime == null || _videoElement!.currentTime > (_lastCapturedTime!.millisecondsSinceEpoch / 1000);

    // Pick a new frame from the camera
    if (  true   ) {

        var frameData = await _readImageData();
        if(frameData != null){
          _curFrameData = (timestamp: _curFrameData.timestamp+1, curFrameData: frameData, isNewData: true);
        }
        //_lastCapturedTime = now;
    }
  }

  /// A heavy function for reading large data
  Future<VideoFrameData?> _readImageData() async{
    // Check if the video element data is available
    if (_videoElement != null &&
        _videoElement!.readyState >= 2 &&  // 2 = HAVE_CURRENT_DATA
        _videoElement!.videoWidth > 0 && _videoElement!.videoHeight > 0) {
          _context!.drawImage(_videoElement!, 0, 0);  
         
      // Get image data from hidden canvas
      final ImageData imageData = _context!.getImageData(0, 0, _width, _height);

      if(imageData.width == _width && imageData.height == _height){ // it's a valid image data
        // Copy the data to the a frame data
        VideoFrameData frameData = VideoFrameData(bytes: Uint8List.fromList(imageData.data), width: _width, height: _height);
        return frameData;
      }
    }

    return null;
  }

  /// Check if camaera is available
  Future<bool> _checkCameraAvailability() async {
    // Check if the browser supports navigator.mediaDevices
    if (window.navigator.mediaDevices == null) {
      return false;
    }

    try{
      // List all available media devices
      final rawDevices = await window.navigator.mediaDevices?.enumerateDevices();
      List<MediaDeviceInfo> devices = rawDevices?.cast<MediaDeviceInfo>() ?? [];

      //List<MediaDeviceInfo> devices = await window.navigator.mediaDevices?.enumerateDevices() as List<MediaDeviceInfo>;

      // Filter out video input devices
      List<MediaDeviceInfo> videoInputDevices = devices.where((device) => device.kind == 'videoinput').toList();

      if (videoInputDevices.isEmpty) {
        return false;
      } 
    } catch(e){
      print('Error accessing the camera: $e');
      return false;
    }

    return true;
  }

}





