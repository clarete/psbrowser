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

/** The main window of the application.
 *
 * This basically manages the three treeviews available for the
 * user. The bookmarks, node and item lists. This class also
 * implements all callbacks fired by the user interface.  */
public class PsBrowser.UI.MainWindow : Builder {
	private Window mwin;
	private Loading loading;
	internal BookmarkStore bmstore;
	internal ConnectionManager connections;
	internal Connection? selected_connection;

	enum NodeListColumns {
		NAME,
		N_COLUMNS
	}

	enum ItemListColumns {
		ID,
		N_COLUMNS
	}

	public MainWindow () {
		try {
			this.add_from_file (
				Resources.get_resource_file ("data/psbrowser.ui"));
		} catch (Error e) {
			critical ("Unable to load ui definition file: %s", e.message);
		}

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
		this.setup_item_list ();
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

	/** Sets up cellrenderers and columns for the node treeview. */
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

	/** Sets up cellrenderers and columns for items treeview. */
	private void setup_item_list () {
		var list = (TreeView) this.get_object ("itemList");

		/* Setting up model */
		var model = new ListStore (
			ItemListColumns.N_COLUMNS,
			typeof (string));
		list.set_model (model);

		/* Renderers and columns */
		var renderer = new CellRendererText ();
		var column = new TreeViewColumn.with_attributes (
			"Id", renderer, "text", 0);
		list.append_column (column);
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

		/* Time to add found node names to their parent came in the
		 * data attribute. */
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

		self.loading.unref_loading ();
		delete cbdata;
		return 0;
	}

	/** Builds a stanza to query for available nodes and sends it to
	 * the pubsub service.
	 *
	 * It is also important to note that this function sets the
	 * parse_list_nodes function as the response callback for this
	 * operation.
	 *
	 * @param conn Is the connection that will be used to send the
	 *  query command.
	 *
	 * @param node_name Is the node that will be queried for its
	 *  childs. If null is passed, then the root node will be queried.
	 *
	 * @param node_iter Is a Gtk.TreeIter containing the node being
	 *  queried. It will be used to build a treeview with found
	 *  nodes. */
	private void list_nodes (Connection conn,
							 string? node_name=null,
							 TreePath? node_path=null) {
		HashTable<string,void*>* cbdata =
		new HashTable<string,void*> (str_hash, str_equal);
		var iq = Pubsub.node_query_nodes (
			conn.bookmark.jid, conn.bookmark.service, node_name);

		/* Clearing the treeview if node name is null */
		if (node_name == null) {
			var node_tree = (TreeView) this.get_object ("nodeList");
			var model = (TreeStore) node_tree.get_model ();
			model.clear ();
		}

		/* Cleaning item model */
		var tview = (TreeView) this.get_object ("itemList");
		((ListStore) tview.model).clear ();

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
		if (res > 0)
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
			/* We have an identical bookmark already added, let's feed
			 * the user back. */
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

		if (this.connections.has_key (bookmark.get_name ())) {
			/* Connection already exists, let's just mark it as the
			 * currentlly selected one. */
			selected_connection = connections.get (bookmark.get_name ());
			this.list_nodes (selected_connection);
		} else {
			/* No connection with the given bookmark? So let's try to
			 * create it and set it as the selected one. */
			var conn = new Connection (bookmark);
			selected_connection = conn;

			/* It is important to put the connection in the connection
			 * manager before authenticating successful to avoid the
			 * needing of handling crazy users activating the same
			 * connection a hundred times. */
			this.connections.set (bookmark.get_name (), conn);

			/* Handling the loading widget visibility by */
			this.loading.ref_loading ();

			/* If everything goes right, just unref the loading widget
			 * and call the list_nodes method. */
			conn.authenticated.connect (() => {
				this.loading.unref_loading ();
				Idle.add (() => {
					this.list_nodes (conn);
					return false;
				});
			});

			/* Humm, things went bad, it was not possible to
			 * authenticate user with given credentials. Time to feed
			 * the user back. */
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

					/* It is important to drop the connection object
					 * from the connection manager. The user will not
					 * be able to try to connect again otherwise.*/
					this.connections.remove (bookmark.get_name ());
					return false;
				});
			});

			try {
				conn.run ();
			} catch (ConnectionError e) {
				this.loading.unref_loading ();
				this.connections.remove (bookmark.get_name ());
				var dialog = new MessageDialog.with_markup (
					this.mwin,
					DialogFlags.MODAL, MessageType.ERROR,
					ButtonsType.OK, "<b>Connection failed</b>");
				dialog.format_secondary_text (e.message);
				dialog.run ();
				dialog.destroy ();
			}
		}
	}

	/* -- item listing functions -- */

	/* -- nodeList callbacks -- */

	private static int parse_node_create (Xmpp.Client client, Iks stanza,
										  void *data) {
		var self = (MainWindow) data;
		self.loading.unref_loading ();
		if (stanza.find_attrib ("type") == "error") {
			unowned Iks error = stanza.find ("error");
			var dialog = new MessageDialog.with_markup (
				self.mwin, DialogFlags.MODAL,
				MessageType.ERROR, ButtonsType.OK,
				"<b>Failed to create node with code %s</b>",
				error.find_attrib ("code"));
			dialog.format_secondary_text (error.child ().name ());

			/* We should not call anything that changes the UI in
			 * another thread, so let's do it in an idle iteration of
			 * the main loop. */
			Idle.add (() => {
				dialog.run ();
				dialog.destroy ();
				return false;
			});
		} else {
			self.list_nodes (self.selected_connection);
		}
		return 0;
	}

	[CCode (instance_pos=-1)]
	public void bt_node_add_cb (Button bt) {
		if (this.selected_connection == null)
			return;
		var bookmark = selected_connection.bookmark;
		var newform = new UI.NewNodeForm (this.mwin);
		var node = newform.get_node (bookmark.jid, bookmark.service);

		/* We have a good Iks node, let's send it to the server */
		if (node != null) {
			/* Requesting the loading widget to be shown */
			this.loading.ref_loading ();

			/* Sending the stanza */
			var res = this.selected_connection.xmpp.send_and_filter (
				node, (Xmpp.ClientAnswerCb) parse_node_create, this);

			/* If sending fails imediatelly, request the hide of
			 * loading widget. */
			if (res > 0)
				this.loading.unref_loading ();
		}
		newform.destroy ();
	}

	[CCode (instance_pos=-1)]
	public bool on_node_list_button_release_cb (Widget widget,
												Gdk.EventButton evt) {
		if (evt.button == 3) {
			var treeview = (TreeView) this.get_object ("nodeList");
			var selection = treeview.get_selection ();
			var rows = selection.get_selected_rows (null);
			if (rows.length () == 0)
				return false;

			var menu = (Menu) this.get_object ("nodeCtxMenu");
			menu.popup (null, null, null, evt.button, evt.time);
		}
		return false;
	}

	private static int parse_node_items (Xmpp.Client client,
										 Iks stza,
										 void *data) {
		var self = (MainWindow) data;
		self.loading.unref_loading ();
		unowned Iks stanza = stza.copy ();

		Idle.add (() => {
			if (stanza.find_attrib ("type") == "error") {
				unowned Iks error = stanza.find ("error");
				var dialog = new MessageDialog.with_markup (
					self.mwin, DialogFlags.MODAL,
					MessageType.ERROR, ButtonsType.OK,
					"<b>Failed to list nodes with code %s</b>",
					error.find_attrib ("code"));
				dialog.format_secondary_text (error.child ().name ());

				/* We should not call anything that changes the UI in
				 * another thread, so let's do it in an idle iteration of
				 * the main loop. */
				dialog.run ();
				dialog.destroy ();
				return false;
			} else {
				/* Traversing to iq > pubsub > items > item*/
				unowned Iks node = stanza.child ().child ().child ();

				/* Getting the item store */
				var model = ((ListStore)
							 ((TreeView) self.get_object ("itemList")).model);

				/* Adding items to the item model */
				while (node != null) {
					TreeIter iter;
					var node_id = node.find_attrib ("id");
					model.append (out iter);
					model.set (iter, 0, node_id);
					node = node.next ();
				}
				return false;
			}
		});
		return 0;
	}

	private void list_items (string node_name, Connection? conn=null) {
		var bookmark = (conn != null ? conn : selected_connection).bookmark;
		var node = Pubsub.node_items (
			bookmark.jid, bookmark.service, node_name);
		this.loading.ref_loading ();

		/* Cleaning model before populating it again */
		var tview = (TreeView) this.get_object ("itemList");
		((ListStore) tview.model).clear ();

		/* Sending node list request */
		var res = this.selected_connection.xmpp.send_and_filter (
			node, (Xmpp.ClientAnswerCb) parse_node_items, this);
		if (res > 0)
			this.loading.unref_loading ();
	}

	[CCode (instance_pos=-1)]
	public void on_node_list_row_activated_cb (TreeView treeview,
											   TreePath path,
											   TreeViewColumn column) {
		/* Getting node name and sending the item list request */
		TreeIter iter;
		Value val;
		treeview.model.get_iter (out iter, path);
		treeview.model.get_value (iter, NodeListColumns.NAME, out val);
		this.list_items (val.get_string ());
	}

	private static int parse_node_delete (Xmpp.Client client, Iks stanza,
										  void *data) {
		var self = (MainWindow) data;
		self.loading.unref_loading ();
		if (stanza.find_attrib ("type") == "error") {
			unowned Iks error = stanza.find ("error");
			var dialog = new MessageDialog.with_markup (
				self.mwin, DialogFlags.MODAL,
				MessageType.ERROR, ButtonsType.OK,
				"<b>Failed to delete node with code %s</b>",
				error.find_attrib ("code"));
			dialog.format_secondary_text (error.child ().name ());

			/* We should not call anything that changes the UI in
			 * another thread, so let's do it in an idle iteration of
			 * the main loop. */
			Idle.add (() => {
				dialog.run ();
				dialog.destroy ();
				return false;
			});
		} else {
			Idle.add (() => {
				self.list_nodes (self.selected_connection);
				return false;
			});
		}
		return 0;
	}

	[CCode (instance_pos=-1)]
	public void on_nl_delete_cb (MenuItem item) {
		/* Getting tree selection */
		var treeview = (TreeView) this.get_object ("nodeList");
		var selection = treeview.get_selection ();
		var rows = selection.get_selected_rows (null);

		/* Getting out if none is selected */
		if (rows.length () < 1)
			return;

		/* Asking the user to ensure the node deletion */
		var dialog = new MessageDialog.with_markup (
			this.mwin, DialogFlags.MODAL, MessageType.QUESTION,
			ButtonsType.YES_NO, "<b>Removing selected node</b>");
		dialog.format_secondary_text (
			"Are you sure you want to remove selected node?");
		var answer = dialog.run () == ResponseType.YES;
		dialog.destroy ();

		/* Yep, he/she wants to procede */
		if (answer) {
			TreeIter iter;
			Value val;
			treeview.model.get_iter (out iter, rows.nth (0).data);
			treeview.model.get_value (iter, 0, out val);

			var bookmark = selected_connection.bookmark;
			var node = Pubsub.node_delete (
				bookmark.jid, bookmark.service, val.get_string ());

			this.loading.ref_loading ();
			var res = this.selected_connection.xmpp.send_and_filter (
				node, (Xmpp.ClientAnswerCb) parse_node_delete, this);
			if (res > 0)
				this.loading.unref_loading ();
		}
	}

	/* -- Public methods -- */

	/** Calls the show_all() method of the main window. */
	public void run () {
		this.mwin.show_all ();
	}
}

