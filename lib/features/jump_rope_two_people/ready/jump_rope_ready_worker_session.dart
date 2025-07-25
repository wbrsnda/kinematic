import 'dart:html';
import 'dart:typed_data';

/// Compile the dart file into js file and put it under the folder where index.html is
/// dart compile js lib/features/jump_rope_two_people/ready/jump_rope_ready_worker_session.dart -o web/workers/jump_rope_ready_worker_session.dart.js

void main() {
  print('[Worker] Started.');
  bool initialized = false;

  final DedicatedWorkerGlobalScope workerScope = DedicatedWorkerGlobalScope.instance; // worker itslef

  workerScope.onMessage.listen((MessageEvent event) {
    final data = event.data; 

    final type = data['type'];

    if (type == 'initialize' && !initialized) {
      //int diffInMilliseconds = DateTime.now().difference(data['time'] as DateTime).inMilliseconds;
      //print('Received the initialize information after ${diffInMilliseconds} ms.');
      
      initialized = true;

      workerScope.postMessage({'type': 'wait_for_data'});
      return;
    }

    if (type == 'frame') {
      // ask for the next data
      workerScope.postMessage({'type': 'wait_for_data'});

      // Process the data
      processFrameData(data);

      // The following is for testing..... Please delete these codes
      
      //print('Received a frame data at time: ${DateTime.now()}');
      final int frameId = data['frameId'];
      final int width = data['width'];
      final int height = data['height'];

      // Send back the received frame data
      final data_back = {
        'type': 'frame',
        'buffer': data['buffer'],
        'width': data['width'],
        'height': data['height'],
        'frameId': data['frameId'],
        'time': DateTime.now(),
      };

      workerScope.postMessage(data_back, [data['buffer']]);
    }
  });
}

void processFrameData(Map frameData){
  // TODO...
}



