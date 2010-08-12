/* bookmarks.vala - This file is part of the psbrowser program
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

using Xml;
using Gee;

namespace PsBrowser {
	/**
	 * Represents a bookmark object
	 */
	public class Bookmark : Object {
		public string jid { get; set; }
		public string password { get; set; }
		public string host { get; set; }
		public int port { get; set; default = 5222; }
		public string service { get; set; }
		public bool status { get; set; default = false; }

		/** Returns the jid concatenated with the service and port */
		public string get_name () {
			return @"$jid:$service:$port";
		}

		/**
		 * Builds a ''Xml.Node'' representing the bookmark object.
		 */
		public Xml.Node to_xml () {
			Xml.Node root = new Xml.Node (null, "bookmark");
			root.set_prop ("jid", this.jid);
			root.set_prop ("password", this.password);
			root.set_prop ("host", this.host);
			root.set_prop ("port", this.port.to_string ());
			root.set_prop ("service", this.service);
			return root;
		}
	}

	private bool bookmark_compare (Bookmark a, Bookmark b) {
		return a.jid == b.jid &&
			a.password == b.password &&
			a.host == b.host &&
			a.port == b.port &&
			a.service == b.service;
	}

    /**
	 * Holds a list of bookmarks
	 */
	public class BookmarkList : ArrayList<Bookmark> {
		public BookmarkList () {
			base ((EqualFunc) bookmark_compare);
		}

		/**
		 * Loads a bunch of bookmarks from a file.
		 *
		 * @param fpath Path of the file to be loaded.
		 */
		public BookmarkList.from_file (string fpath) throws FileError {
			string output;
			FileUtils.get_contents (fpath, out output);
			this.from_string (output);
		}

		/** Loads bookmarks from an XML string */
		public BookmarkList.from_string (string xml) {
			this ();
			Doc* doc = Parser.parse_doc (xml);
			Xml.Node root = doc->get_root_element ();
			for (Xml.Node* iter = root.children; iter != null;
				 iter = iter->next) {
				if (iter->name == "bookmark") {
					var bookmark = new Bookmark ();
					bookmark.jid = iter->get_prop ("jid");
					bookmark.password = iter->get_prop ("password");
					bookmark.port = iter->get_prop ("port").to_int ();
					bookmark.host = iter->get_prop ("host");
					bookmark.service = iter->get_prop ("service");
					this.add (bookmark);
				}
			}
		}

		/** Write an xml with all bookmarks held by this list */
		public Doc* to_xml () {
			/* Building and setting up document */
			Xml.Doc* doc = new Xml.Doc ("1.0");
			Xml.Node* root = new Xml.Node (null, "bookmarks");
			doc->set_root_element (root);
			foreach (var bm in this)
				root->add_child (bm.to_xml ());
			return doc;
		}

		/** Save current list of bookmarks to a file */
		public void save (string fpath) {
			this.to_xml ()->save_file (fpath);
		}
	}
}
