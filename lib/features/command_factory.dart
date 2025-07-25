
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
library;

import 'base_command.dart';

typedef CmdList = List<BaseCommand>;

/// ## CommandFactory
/// 
/// ### CommandFactory is a factory class which creates a global instance for each command.  
/// 
/// The CommandFactory manages all command instances and provides an access to each one
class CommandFactory {

  /// List of commands currently running
  /// Typically, only one live command in the list 
  static final CmdList _liveCmdList = <BaseCommand>[];  

  /// Get number of alive command
  static int get numberOfLiveCommands => _liveCmdList.length;

  /// Stop all alive commands
  static Future<void> stopAllLiveCmd() async{
    var tempCmdList = _liveCmdList;
    for(var cmd in tempCmdList){
       await cmd.endCmd();
    }
  }

  /// Add a command to the live list when it starts to run
  static void addToLiveList_(BaseCommand refCommand){
    if( !_liveCmdList.contains(refCommand) ){
       _liveCmdList.add(refCommand); 
    }
  }

  /// Remove a command from the live list when it stops
  static void delLiveCmd_(BaseCommand refCommand){
    if (_liveCmdList.contains(refCommand)) {
      _liveCmdList.remove(refCommand);
    }
  }

  // The concrete commands in the factory
  static final JumpRopeReadyCommand _jumpRopeReadyCommand = JumpRopeReadyCommand();
  static JumpRopeReadyCommand get jumpRopeReadyCommand => _jumpRopeReadyCommand;
}
