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
		private Loading loading;
		internal BookmarkStore bmstore;
		internal ConnectionManager connections;

		public MainWindow () {
			this.add_from_file ("data/psbrowser.ui");

			/* Setting up connection list */
			this.connections = new ConnectionManager ();

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
			bmstore = new UI.BookmarkStore ();
			serverList.set_model (bmstore);

			/* Renderers and columns */
			var rendererp = new CellRendererPixbuf ();
			var column0 = new TreeViewColumn.with_attributes (
				"", rendererp, "pixbuf", 0);
			serverList.append_column (column0);

			var renderer = new CellRendererText ();
			var column1 = new TreeViewColumn.with_attributes (
				"JID", renderer, "markup", 1);
			serverList.append_column (column1);
		}

		// -- Callbacks --

		static void bt_bookmark_add_cb (Button bt, void *data) {
			var self = (MainWindow) data;
			var nbform = new UI.NewBookmarkForm (self.mwin);
			var bookmark = nbform.run ();
			if (bookmark == null) {
				/* User have canceled the add operation. Time to
				 * destroy the form. */
				nbform.destroy ();
				return;
			}

			while (self.bmstore.contains (bookmark)) {
				/* We have an identical bookmark already added, let's
				 * feed the user back. */
				var dialog = new MessageDialog.with_markup (self.mwin,
					DialogFlags.MODAL, MessageType.INFO,
					ButtonsType.OK, "<b>Bookmark already exists</b>");
				dialog.format_secondary_text (
					"Please change the JID or service info and try again");
				dialog.run ();
				dialog.destroy ();
				bookmark = nbform.get_bookmark ();

				/* User have gave up on adding a new bookmark */
				if (bookmark == null) {
					nbform.destroy ();
					return;
				}
			}

			/* It's everything ok, let's add the bookmark to our
			 * list model and destroy the form. */
			self.bmstore.append_data (bookmark);
			nbform.destroy ();
		}

		static void bt_bookmark_remove_cb (Button bt, void *data) {
			var self = (MainWindow) data;
			var server_list = (TreeView) self.get_object ("serverList");
			var selection = server_list.get_selection ();
			var rows = selection.get_selected_rows (null);

			/* We don't need to do anything if nothing is selected */
			if (rows.length () == 0)
				return;

			var dialog = new MessageDialog.with_markup (
				self.mwin, DialogFlags.MODAL, MessageType.QUESTION,
				ButtonsType.YES_NO, "<b>Removing selected bookmark</b>");
			dialog.format_secondary_text (
				"Are you sure you want to remove selected bookmark?");
			if (dialog.run () == ResponseType.YES) {
				foreach (var row in rows) {
					self.bmstore.remove_index (row.get_indices ()[0]);
				}
			}
			dialog.destroy ();
		}

		static void connect_cb (TreeView treeview, TreePath path,
								TreeViewColumn column, void *data) {
			var self = (MainWindow) data;
			var iter = TreeIter ();

			self.bmstore.get_iter (out iter, path);
			var bookmark = (Bookmark) iter.user_data;

			if (!self.connections.has_key (bookmark.get_name ())) {
				var conn = new Connection (bookmark);
				self.connections.set (bookmark.get_name (), conn);
				conn.run ();
			}
		}

		private void setup_signals () {
			// Main window
			Signal.connect (this.mwin, "destroy", Gtk.main_quit, null);

			// Bookmark manager buttons
			Signal.connect (this.get_object ("btBookmarkAdd"), "clicked",
							(GLib.Callback) bt_bookmark_add_cb, this);
			Signal.connect (this.get_object ("btBookmarkRemove"), "clicked",
							(GLib.Callback) bt_bookmark_remove_cb, this);

			// Connection management
			Signal.connect (this.get_object ("serverList"), "row-activated",
							(GLib.Callback) connect_cb, this);
		}

		// -- Public methods --

		public void run () {
			this.mwin.show_all ();
		}
	}
}
