
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
library command_lib;

import 'dart:html';
import 'dart:js' as js;
import 'dart:typed_data';
import 'package:js/js_util.dart' as js_util;
import 'package:jumping_game/scene_repository/jump_rope_repository.dart';
import 'package:jumping_game/scene_repository/repository_factory.dart';
import 'package:jumping_game/data_stream/video_stream_capture.dart';
import 'package:jumping_game/unity/simple_parameters.dart';
import 'command_factory.dart';

part 'jump_rope_two_people/ready/jump_rope_ready_command.dart'; // 关联子类文件

/// ## BaseCommand
///
/// ### Superclass of the commands
///
/// This class is used for implementing the processing operations in a feature. 
///
/// **Note**: A command does not handle the interaction with view.
///
/// If a command includes a loop for data processing, it typically performs it in a separate thread
///
/// {@template command_example_usage}
/// Example usage:
///
/// ```dart
///  // Get the handle of the command from the factory, 
///  // e.g., the command of JumpRopeReadyCommand
///  var refCommand = CommandFactory.jumpRopeReadyCommand;

///  try{
///    if(refCommand.isAlive()){
///      await refCommand.beginCmd(); // start to run the command 
///    }
///    else{
///      await refCommand.endCmd(); // stop the command
///    }     
///  }catch(e){
///    print('Error occurs when starting/stopping the command: $e');
///  }
/// ```
/// {@endtemplate }
abstract class BaseCommand {

  // the command status
  bool _isAlive = false;  

	/// Begin a command. The specific behaviors are implemented in 
	/// [beginCmdImplement] of the subclass
  ///  
	Future<void> beginCmd() async{
      if(_isAlive) return;

    	_modifyOtherCmdState();  // Modify the status of the currently running commands

	    _isAlive = true; 
      CommandFactory.addToLiveList_(this);

	    await _beginCmdImplement(); // start running
  }

  /// Stop a command. The specific behaviors are implemented in 
	/// [endCmdImplement] of the subclass
  ///  
	Future<void> endCmd() async{
    if(!_isAlive) return;

    _isAlive = false; 
	  await _endCmdImplement(); 

	  CommandFactory.delLiveCmd_(this);
  }

	/// If this command is running.
	bool isAlive() => _isAlive;
	
  // Internal functions

  /// {@template modify_other_command_state}
	/// When a command is invoked, it should do something for other 
	/// currently running commands in this function.
  /// 
	/// In default, it deactivates currently alive commands. 
  /// This default behavior can be overrided by a specific command   
  /// {@endtemplate}
	Future<void> _modifyOtherCmdState() async {
    // Default: stop alive cmds before a new command
    await CommandFactory.stopAllLiveCmd();
  }

	/// {@template begin_command_implement}
  /// To start the operations of a specific command
  /// 
  /// This method should be implemented 
  /// {@endtemplate}
	Future<void> _beginCmdImplement();

  /// {@template end_command_implement}
  /// To stop the operations of a specific command
  /// 
  /// This method should be implemented 
  /// {@endtemplate}
	Future<void> _endCmdImplement();

  
} 