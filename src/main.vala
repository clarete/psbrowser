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
using Iksemel;
using Taningia;
using PsBrowser;

class MainWindow : Builder {

	private Window mwin;
	private UI.Loading loading;
	private Taningia.Log logger;

	public MainWindow () throws Error {
		this.add_from_file ("data/psbrowser.ui");

		// Logging setup
		this.logger = new Taningia.Log ("psbrowser");
		this.logger.set_level (Taningia.LogLevel.DEBUG);
		this.logger.set_use_colors(true);

		// Layout
		this.layout_setup ();
		this.signal_setup ();
	}

	// -- Layout stuff

	private void layout_setup () {
		this.mwin = (Window) this.get_object ("mainWindow");
		this.loading = new UI.Loading ();

		// Fancy white header
		var eventbox = (EventBox) this.get_object ("titleEventbox");
		Gdk.Color white;
		Gdk.Color.parse ("#fff", out white);
		eventbox.get_colormap ().alloc_color (white, true, true);
		eventbox.modify_bg (Gtk.StateType.NORMAL, white);

		// Positioning loading widget
		((Box) this.get_object ("hboxTop")).pack_end (
			this.loading, false, false, 0);

		// ServerList TreeView column setup
		var serverList = (TreeView) this.get_object ("serverList");
		var renderer = new CellRendererText ();
		var column = new TreeViewColumn.with_attributes (
			"Service", renderer, "markup", 0);
		serverList.append_column (column);
		var column1 = new TreeViewColumn.with_attributes (
			"JID", renderer, "markup", 1);
		serverList.append_column (column1);

		// Treeview models
		var bmstore = new UI.BookmarkStore.from_file ("bleh.xml");
		serverList.set_model (bmstore);
	}

	private void signal_setup () {
		this.mwin.destroy.connect (Gtk.main_quit);
	}

	// -- public methods --

	public void run () {
		this.mwin.show_all ();
		this.loading.unref_loading ();
	}
}

int
main (string[] args)
{
	Gtk.init(ref args);

	try {
		var mwin = new MainWindow ();
		mwin.run();
	} catch (Error e) {
		stderr.printf ("Error: %s\n", e.message);
	}

	Gtk.main();
	return 0;
}
