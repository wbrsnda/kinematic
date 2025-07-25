
/// **Author**: wwyang
/// **Date**: 2025.5.8
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

import 'base_repository.dart';
import 'jump_rope_repository.dart';

/// ## RepositoryFactory
/// 
/// ### RepositoryFactory is a factory class which creates a global instance for each repository.  
/// 
/// The RepositoryFactory manages all repository instances and provides an access to each one 
class RepositoryFactory {

  /// List of all the created repositories  
  static final List<BaseRepository> _repositoryList = <BaseRepository>[];  

  /// Add a repoistory to the factory
  static void addToFactory_(BaseRepository refRepository){
    if( !_repositoryList.contains(refRepository) ){
       _repositoryList.add(refRepository); 
    }
  }

  /// destroy all repository
  static Future<void> freeAllRepository() async{
    for(var repos in _repositoryList){
       await repos.freeRepository();
    }
  }

  // The concrete repositories in the factory
  static final JumpRopeRepository _jumpRopeReadyRepository = JumpRopeRepository();
  static JumpRopeRepository get jumpRopeReadyRepository => _jumpRopeReadyRepository;

}
