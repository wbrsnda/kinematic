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
library repository_lib;

import 'base_repository.dart';
import 'package:jumping_game/data_stream/video_stream_capture.dart' as video_capture;

/// ## JumpRopeRepository

/// ### Instanceclass of the repository
///
/// This class is used for managing data in the features of jump_rope_two_people.   
class JumpRopeRepository extends BaseRepository {
  
  /// video image of the current frame
  video_capture.VideoFrameData? curframeData;
  
  /// timestamp of the current frame
  int curFrameID = 0;

  /// information used for the 'ready' sub-feature
  final JumpRopeReadyInformation _jumpRopeReadyInformation = JumpRopeReadyInformation();

  /// Get the 'ready' information
  JumpRopeReadyInformation get jumpRopeReadyInformation => _jumpRopeReadyInformation;
  
  /// {@macro free_repository}
  @override
  Future<void> freeRepository() async{
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
  bool hasBodyInLeftBox = false;      // whether a body in the left box
  int bodyDurationInLeftBox = 0;      // duration time of current body staying in the left box 

  bool hasBodyInRightBox = false;     // whether a body in the right box
  int bodyDurationInRightBox = 0;     // duration time of current body staying in the right box 

  bool isReady = false;               // whether the jumping is ready

  /// **Note:** you can modify it 
  /// according to your need
  int bodyDurationTimeMax = 60;       // seconds: beyond this time, the jumping is automatically ready
}

