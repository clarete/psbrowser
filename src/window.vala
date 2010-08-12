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
using Taningia;
using Iksemel;

namespace PsBrowser.UI {
	/** The main window of the application.
	 *
	 * This basically manages the three treeviews available for the
	 * user. The bookmarks, node and item lists. This class also
	 * implements all callbacks fired by the user interface.  */
	public class MainWindow : Builder {

		private Window mwin;
		private Loading loading;
		internal BookmarkStore bmstore;
		internal ConnectionManager connections;

		enum NodeListColumns {
			NAME,
			N_COLUMNS
		}

		public MainWindow () {
			this.add_from_file ("data/psbrowser.ui");

			/* Setting up connection list */
			this.connections = new ConnectionManager ();

			/* Getting/Creating important widgets */
			this.mwin = (Window) this.get_object ("mainWindow");
			this.loading = new UI.Loading ();

			/* Calling all layout setup methods */
			this.setup_title ();
			this.setup_loading ();
			this.setup_bookmark_list ();
			this.setup_node_list ();
			this.connect_signals (this);
		}

		/* -- Layout stuff -- */

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

			/* Model setup */
			try {
				bmstore = new UI.BookmarkStore.from_file (
					Resources.get_conf_file ("bookmarks.xml"));
			} catch (FileError e) {
				bmstore = new UI.BookmarkStore ();
			}
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

		/** Sets up cellrenderers and columns for the node
		 * treeview. */
		private void setup_node_list () {
			var node_list = (TreeView) this.get_object ("nodeList");

			/* Setting up model */
			var model = new TreeStore (
				NodeListColumns.N_COLUMNS,
				typeof (string));
			node_list.set_model (model);

			/* Renderers and columns */
			var renderer = new CellRendererText ();
			var column = new TreeViewColumn.with_attributes (
				"Node", renderer, "markup", 0);
			node_list.append_column (column);
		}

		/* -- node listing functions -- */

		/** Parses a list of nodes when they're received from the xmpp
		 * client of a connection. */
		private static int parse_list_nodes (Xmpp.Client client,
											 Iks stanza, void *data) {
			var cbdata = (HashTable<string, void*> *) data;
			var self = (MainWindow) cbdata->lookup ("instance");
			var conn = (Connection) cbdata->lookup ("connection");

			var treeview = (TreeView) self.get_object ("nodeList");
			var model = (TreeStore) treeview.get_model ();
			var parent_path = (TreePath *) cbdata->lookup ("user_data");

			/* Traversing to the iq > query > item node. */
			unowned Iks node = stanza.find ("query").child ();

			/* Time to add found node names to their parent came in
			 * the data attribute. */
			while (node != null) {
				TreeIter iter, parent;
				var node_name = node.find_attrib ("node");
				if (node_name == null)
					break;

				if (parent_path != null) {
					model.get_iter (out parent, parent_path);
					model.append (out iter, parent);
				} else {
					model.append (out iter, null);
				}
				model.set (iter, NodeListColumns.NAME, node_name);

				/* Calling list_nodes again but now passing the child
				 * found. */
				var path = (TreePath*) model.get_path (iter);
				self.list_nodes (conn, node_name, path);
				node = node.next ();
			}

			if (parent_path != null) {
				delete parent_path;
			}

			delete cbdata;
			return 0;
		}

		/** Builds a stanza to query for available nodes and sends it
		 * to the pubsub service.
		 *
		 * It is also important to note that this function sets the
		 * parse_list_nodes function as the response callback for this
		 * operation.
		 *
		 * @param conn Is the connection that will be used to send the
		 *  query command.
		 *
		 * @param node_name Is the node that will be queried for its
		 *  childs. If null is passed, then the root node will be
		 *  queried.
		 *
		 * @param node_iter Is a Gtk.TreeIter containing the node
		 *  being queried. It will be used to build a treeview with
		 *  found nodes. */
		private void list_nodes (Connection conn,
								 string? node_name=null,
								 TreePath? node_path=null) {
			HashTable<string,void*>* cbdata =
				new HashTable<string,void*> (str_hash, str_equal);
			var iq = Pubsub.node_query_nodes (
				conn.bookmark.jid, conn.bookmark.service, node_name);

			/* Asking to show the loading widget. */
			this.loading.ref_loading ();

			/* Sending the stanza and registering parse_list_nodes as
			 * the answer callback. */
			cbdata->insert ("instance", this);
			cbdata->insert ("connection", conn);
			cbdata->insert ("user_data", (void *) node_path);
			var res = conn.xmpp.send_and_filter (
				iq, (Xmpp.ClientAnswerCb) parse_list_nodes, cbdata);

			/* We have to give up on show loading if something goes
			 * wrong. */
			if (res == 0)
				this.loading.unref_loading ();
		}

		/* -- Callbacks -- */

		[CCode (instance_pos=-1)]
		public void bt_bookmark_add_cb (Button bt) {
			var nbform = new UI.NewBookmarkForm (this.mwin);
			var bookmark = nbform.run ();
			if (bookmark == null) {
				/* User have canceled the add operation. Time to
				 * destroy the form. */
				nbform.destroy ();
				return;
			}

			while (this.bmstore.contains (bookmark)) {
				/* We have an identical bookmark already added, let's
				 * feed the user back. */
				var dialog = new MessageDialog.with_markup (this.mwin,
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
			this.bmstore.append_data (bookmark);
			this.bmstore.save (Resources.get_conf_file ("bookmarks.xml"));
			nbform.destroy ();
		}

		[CCode (instance_pos=-1)]
		public void bt_bookmark_remove_cb (Button bt) {
			var server_list = (TreeView) this.get_object ("serverList");
			var selection = server_list.get_selection ();
			var rows = selection.get_selected_rows (null);

			/* We don't need to do anything if nothing is selected */
			if (rows.length () == 0)
				return;

			var dialog = new MessageDialog.with_markup (
				this.mwin, DialogFlags.MODAL, MessageType.QUESTION,
				ButtonsType.YES_NO, "<b>Removing selected bookmark</b>");
			dialog.format_secondary_text (
				"Are you sure you want to remove selected bookmark?");
			if (dialog.run () == ResponseType.YES) {
				foreach (var row in rows) {
					this.bmstore.remove_index (row.get_indices ()[0]);
				}
				this.bmstore.save (Resources.get_conf_file ("bookmarks.xml"));
			}
			dialog.destroy ();
		}

		[CCode (instance_pos=-1)]
		public void connect_cb (TreeView treeview, TreePath path,
								TreeViewColumn column) {
			var iter = TreeIter ();

			this.bmstore.get_iter (out iter, path);
			var bookmark = (Bookmark) iter.user_data;

			/* No connection with the given bookmark? So let's try to
			 * do it. */
			if (!this.connections.has_key (bookmark.get_name ())) {
				var conn = new Connection (bookmark);

				/* It is important to put the connection in the
				 * connection manager before authenticating successful
				 * to avoid the needing of handling crazy users
				 * activating the same connection a hundred times. */
				this.connections.set (bookmark.get_name (), conn);

				/* Handling the loading widget visibility by */
				this.loading.ref_loading ();

				/* If everything goes right, just unref the loading
				 * widget and call the list_nodes method. */
				conn.authenticated.connect (() => {
					this.loading.unref_loading ();

					/* The user has clicked in a bookmark, so we have
					 * to clear the model in order to show only
					 * entries of that bookmark.  */
					var node_tree = (TreeView) this.get_object ("nodeList");
					var model = (TreeStore) node_tree.get_model ();
					model.clear ();

					this.list_nodes (conn);
				});

				/* Humm, things went bad, it was not possible to
				 * authenticate user with given credentials. Time to
				 * feed the user back. */
				conn.authfailed.connect (() => {
					/* First of all, let's hide the loading widget. */
					this.loading.unref_loading ();

					/* Now, let's queue a message dialog to be shown
					 * informing the user that his credentials are not
					 * ok. */
					Idle.add (() => {
						var dialog = new MessageDialog.with_markup (
							this.mwin,
							DialogFlags.MODAL, MessageType.INFO,
							ButtonsType.OK, "<b>Authentication failed</b>");
						dialog.format_secondary_text (
							"Edit bookmark options and then try again.");
						dialog.run ();
						dialog.destroy ();

						/* It is important to drop the connection
						 * object from the connection manager. The
						 * user will not be able to try to connect
						 * again otherwise.*/
						this.connections.remove (bookmark.get_name ());
						return false;
					});
				});
				conn.run ();
			}
		}

		/* -- item listing functions -- */

		/* -- nodeList callbacks -- */

		[CCode (instance_pos=-1)]
		public bool on_node_list_button_press_cb (Widget widget,
												  Gdk.EventButton evt) {
			if (evt.button == 3) {
				var menu = (Menu) this.get_object ("nodeCtxMenu");
				menu.popup (null, null, null, evt.button, evt.time);
			}
			return false;
		}

		[CCode (instance_pos=-1)]
		public void on_node_list_row_activated_cb (TreeView treeview,
												   TreePath path,
												   TreeViewColumn column,
												   void *data) {
			TreeIter iter;
			Value val;
			treeview.model.get_iter (out iter, path);
			treeview.model.get_value (iter, NodeListColumns.NAME, out val);
		}

		/* -- Public methods -- */

		/** Calls the show_all() method of the main window. */
		public void run () {
			this.mwin.show_all ();
		}
	}
}
