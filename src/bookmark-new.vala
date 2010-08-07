/* bookmarks-new.vala - This file is part of the psbrowser program
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
	public class NewBookmarkForm : Builder {
		Dialog dialog;

		public NewBookmarkForm (Window? parent) {
			this.add_from_file ("data/newbookmark.ui");
			this.dialog = (Dialog) this.get_object ("mainDialog");
			if (parent != null)
				this.dialog.set_transient_for (parent);

			// Glade is not setting the default value of the port
			// input, so let's do it ourselves.
			((SpinButton) this.get_object ("portEntry"))
			    .get_adjustment ()
			    .set_value (5222.0);

			// Filling function callback
			Signal.connect (this.get_object ("jidEntry"), "changed",
							(GLib.Callback) fill_jid_dependent_fields, this);

			// Validation callbacks
			Signal.connect (this.get_object ("jidEntry"), "changed",
							(GLib.Callback) validate, this);
			Signal.connect (this.get_object ("passwordEntry"), "changed",
							(GLib.Callback) validate, this);
			Signal.connect (this.get_object ("hostEntry"), "changed",
							(GLib.Callback) validate, this);
			Signal.connect (this.get_object ("pserviceEntry"), "changed",
							(GLib.Callback) validate, this);
			Signal.connect (this.get_object ("portEntry"), "changed",
							(GLib.Callback) validate, this);
		}

		static void fill_jid_dependent_fields (Entry entry, void *data) {
			var self = (NewBookmarkForm) data;
			var jid = entry.get_text ();
			var id = new Iksemel.Id (new Iksemel.Stack (64, 128), jid);

			if ((id.user != null && id.user.length != 0) &&
				(id.server != null && id.server.length != 0)) {
				// JID seems to be ok, let's fill host and pubsub
				// fields.
				var server = id.server;
				((Entry) self.get_object ("hostEntry")).set_text (server);
				((Entry) self.get_object ("pserviceEntry")).set_text (
					@"pubsub.$server");
			} else {
				// No usable JID, let's reset host and pubsub fields.
				((Entry) self.get_object ("hostEntry")).set_text ("");
				((Entry) self.get_object ("pserviceEntry")).set_text ("");
			}
		}

		static void validate (GLib.Object entry, void *data) {
			var self = (NewBookmarkForm) data;
			string jid, password, host, service;
			int port;
			bool sensitive;
			jid = ((Entry) self.get_object ("jidEntry")).get_text ();
			password = ((Entry) self.get_object ("passwordEntry")).get_text ();
			host = ((Entry) self.get_object ("hostEntry")).get_text ();
			service = ((Entry) self.get_object ("pserviceEntry")).get_text ();
			port = ((SpinButton) self.get_object ("portEntry"))
			    .get_value_as_int ();

			sensitive = (jid.length > 0 && password.length > 0 &&
						 host.length > 0 && port > 0);
			((Button) self.get_object ("buttonOk")).set_sensitive (sensitive);
		}

		public Bookmark? get_bookmark () {
			Bookmark bookmark = null;
			if (dialog.run () == 1) {
				bookmark = new Bookmark ();
				bookmark.jid =
					((Entry) this.get_object ("jidEntry")).get_text ();
				bookmark.password =
					((Entry) this.get_object ("passwordEntry")).get_text ();
				bookmark.host =
					((Entry) this.get_object ("hostEntry")).get_text ();
				bookmark.service =
					((Entry) this.get_object ("pserviceEntry")).get_text ();
				bookmark.port =
					((SpinButton) this.get_object ("portEntry"))
				        .get_value_as_int ();
			}
			return bookmark;
		}

		public Bookmark? run () {
			return this.get_bookmark ();
		}

		public void destroy () {
			dialog.destroy ();
		}
	}
}
