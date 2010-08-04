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

using Taningia;
using Iksemel;

/** Manages a single connection to a pubsub (xmpp) service. */
public class PsBrowser.Connection : Object {
	public signal void connected ();
	public signal void disconnected ();
	public signal void authenticated ();
	public signal void authfailed ();

	public Bookmark bookmark { private set; get; }
	public Xmpp.Client xmpp { private set; get; }

	/** Fires the "authenticated" signal and sends presence */
	static int auth_cb (Xmpp.Client client, void *data1, void *data2) {
		Connection conn = (Connection) data2;
		Iks pres = make_pres (ShowType.AVAILABLE, "Online");
		client.send (pres);
		conn.authenticated ();
		return 0;
	}

	/** Disconnects the xmpp client and fires "authfailed" signal */
	static int auth_failed_cb (Xmpp.Client client, void *data1, void *data2) {
		Connection conn = (Connection) data2;
		client.disconnect ();
		conn.authfailed ();
		return 0;
	}

	/** Sets up bookmark for this connection and its xmpp client.
	 *
	 * Each connection have its own connection.
	 */
	public Connection (Bookmark bookmark) {
		this.bookmark = bookmark;
		this.xmpp = new Xmpp.Client (
			bookmark.jid, bookmark.password,
			bookmark.host, bookmark.port);
		this.xmpp.event_connect (
			"authenticated", auth_cb, this);
		this.xmpp.event_connect (
			"authenticated-failed", auth_failed_cb, this);

		/* Setting up taningia logging */
		unowned Taningia.Log ilogger = this.xmpp.get_logger ();
		ilogger.set_level (Taningia.LogLevel.DEBUG);
		ilogger.set_use_colors (true);
	}

	/** Calls the connect() and run() methods of the XMPP client. */
	public void run () {
		this.xmpp.connect ();
		this.xmpp.run (true);
	}
}
