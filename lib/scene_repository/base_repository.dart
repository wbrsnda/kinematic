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
library repository_lib;

import 'repository_factory.dart';

/// ## BaseRepository
///
/// ### Superclass of the repositories 
///
/// This class is used for implementing the respository that contains various scene data
///
/// **Note**: The repository is only used for storing data but not for processing the data
///
abstract class BaseRepository {

  /// The repository is automatically added into the factory when being created
  BaseRepository(){
    RepositoryFactory.addToFactory_(this);
  }

  /// {@template free_repository}
  /// Free the repository
  /// 
  /// This method should be implemented for a repository sub-class
  /// {@endtemplate}
	Future<void> freeRepository();
}

