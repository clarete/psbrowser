/* resources.vala - This file is part of the psbrowser program
 *
 * Copyright (C) 2010  Lincoln de Sousa <lincoln@comum.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace PsBrowser.Resources {
	public string get_conf_file (string basename) {
		string conf_dir = Path.build_filename (
			Environment.get_home_dir(), ".config", "psbrowser");
		DirUtils.create_with_parents (conf_dir, 0775);
		return Path.build_filename (conf_dir, basename);
	}

	public string get_resource_file (string basename) {
		return Path.build_filename (Config.PKGDATADIR, basename);
	}
}
