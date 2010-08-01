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

namespace PsBrowser.UI {
	public class MainWindow : Builder {

		private Window mwin;
		private UI.Loading loading;

		public MainWindow () {
			this.add_from_file ("data/psbrowser.ui");

			// Getting/Creating important widgets
			this.mwin = (Window) this.get_object ("mainWindow");
			this.loading = new UI.Loading ();

			// Calling all layout setup methods
			this.setup_title ();
			this.setup_loading ();
			this.setup_bookmark_list ();
			this.setup_signals ();
		}

		// -- Layout stuff --

		/** Sets up the fancy white header */
		private void setup_title () {
			var eventbox = (EventBox) this.get_object ("titleEventbox");
			Gdk.Color white;
			Gdk.Color.parse ("#fff", out white);
			eventbox.get_colormap ().alloc_color (white, true, true);
			eventbox.modify_bg (Gtk.StateType.NORMAL, white);
		}

		/** Sets the positioning of loading widget */
		private void setup_loading () {
			((Box) this.get_object ("hboxTop")).pack_end (
				this.loading, false, false, 0);
			this.loading.set_no_show_all (true);
		}

		/** Creates and associates columns and cellrenderers to the
		 * bookmark TreeView (serverList). */
		private void setup_bookmark_list () {
			var serverList = (TreeView) this.get_object ("serverList");

			// Model setup
			var bmstore = new UI.BookmarkStore ();
			serverList.set_model (bmstore);

			// Renderers and columns
			var renderer = new CellRendererText ();
			var column = new TreeViewColumn.with_attributes (
				"Service", renderer, "markup", 0);
			serverList.append_column (column);
			var column1 = new TreeViewColumn.with_attributes (
				"JID", renderer, "markup", 1);
			serverList.append_column (column1);
		}

		// -- Callbacks --

		[CCode (instance_pos=-1)]
		void bt_bookmark_add_cb (Button bt, void *data) {
			Window win = (Window) data;
			new UI.NewBookmarkForm (win).run ();
		}

		private void setup_signals () {
			// Main window
			Signal.connect (this.mwin, "destroy", Gtk.main_quit, null);

			// Bookmark manager buttons
			Signal.connect (this.get_object ("btBookmarkAdd"), "clicked",
							(GLib.Callback) bt_bookmark_add_cb, this.mwin);
		}

		// -- Public methods --

		public void run () {
			this.mwin.show_all ();
		}
	}
}
