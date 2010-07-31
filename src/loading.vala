/* main.vala - This file is part of the psbrowser program
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

using Gtk;

namespace PsBrowser {

    /**
	 * An abstraction for a loading widget that is shown when some async
	 * job is running. You can use the .{un,}ref_loading() methods to ask
	 * for showing or hidding it.
	 */
	class Loading : Image {
		private int _is_loading = 0;

		public Loading () {
			this.set_from_file ("data/pixmaps/loading.gif");
		}

		/**
		 * Changes the visibility property of our `loading' image
		 * based on the `self.is_loading' flag. This is important
		 * because more than one action can request to show/hide it at
		 * the same time.
		 */
		private void _handle_loading () {
			this.set_visible (this._is_loading > 0);
		}

		/**
		 * Increment the loading request and call the loading
		 * show/hide function.
		 */
		public void ref_loading () {
			this._is_loading++;
			this._handle_loading ();
		}

		/**
		 * Decrement the loading request and call the loading
		 * show/hide function.
		 */
		public void unref_loading () {
			this._is_loading = int.max (0, this._is_loading - 1);
			this._handle_loading ();
		}
	}
}
