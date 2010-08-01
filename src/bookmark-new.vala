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

			Signal.connect (this.get_object ("jidEntry"), "changed",
							(GLib.Callback) fill_jid_dependent_fields, this);

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

		public Bookmark? run () {
			Bookmark bookmark = null;
			if (dialog.run () == 1)
				stdout.printf ("Ok\n");
			else
				stdout.printf ("Cancel\n");
			dialog.destroy ();
			return bookmark;
		}
	}
}
