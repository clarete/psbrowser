/* bookmark-store.vala - This file is part of the psbrowser program
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
using Gdk;
using Gee;

namespace PsBrowser.UI {
	public class BookmarkStore : BookmarkList, TreeModel {
		private ArrayList<Type> column_headers;
		private int stamp;

		enum Columns {
			STATUS,
			JID,
			SERVICE,
			N_COLUMNS
		}

		construct {
			this.stamp = (int) Random.next_int ();
			this.column_headers = new ArrayList<Type> ();

			/* STATUS */
			this.column_headers.add (typeof (Gdk.Pixbuf));

			/* JID */
			this.column_headers.add(typeof (string));

			/* SERVICE */
			this.column_headers.add(typeof (string));
		}

		public BookmarkStore () {
			base ();
		}

		public BookmarkStore.from_file (string fpath) throws FileError {
			BookmarkList.from_file (fpath);
		}

		public BookmarkStore.from_string (string xml) {
			BookmarkList.from_string (xml);
		}

		public TreeModelFlags get_flags () {
			return TreeModelFlags.ITERS_PERSIST | TreeModelFlags.LIST_ONLY;
		}

		public Type get_column_type (int index) {
			return this.column_headers[index];
		}

		public int get_n_columns () {
			return Columns.N_COLUMNS;
		}

		public TreePath get_path (TreeIter iter) {
			var path = new TreePath ();
			path.append_index (this.index_of ((Bookmark) iter.user_data));
			return path;
		}

		public bool get_iter (out TreeIter iter, TreePath path) {
			int index = path.get_indices ()[0];
			if (index >= this.size) {
				iter.stamp = 0;
				return false;
			} else {
				Bookmark bookmark = ((BookmarkList) this).get (index);
				iter.stamp = this.stamp;
				iter.user_data = bookmark.ref ();
				return true;
			}
		}

		public void get_value (TreeIter iter, int column, out Value value) {
			Bookmark bookmark = (Bookmark) iter.user_data;
			/* Time to setup the correct value depending on the column */
			value.init (this.column_headers[column]);
			switch (column) {
			case Columns.STATUS:
				Pixbuf pixbuf;
				try {
					if (bookmark.status)
						pixbuf = new Pixbuf.from_file (
							Resources.get_resource_file (
								"data/pixmaps/online.png"));
					else
						pixbuf = new Pixbuf.from_file (
							Resources.get_resource_file (
								"data/pixmaps/offline.png"));
					value.set_object (pixbuf);
				} catch (Error e) {
					critical ("Unable to load pixbuf file: %s", e.message);
				}
				break;
			case Columns.JID:
				value.set_string (bookmark.jid);
				break;
			case Columns.SERVICE:
				value.set_string (bookmark.service);
				break;
			}
		}

		public bool iter_children (out TreeIter iter, TreeIter? parent) {
			// It's a list model not a tree model. So, our nodes have
			// no parent.
			if (parent != null) {
				iter.stamp = 0;
				return false;
			}

			if (this.size > 0) {
				// Let's point to the first element of this list
				Bookmark bookmark = ((BookmarkList) this).get (0);
				iter.stamp = this.stamp;
				iter.user_data = bookmark;
				return true;
			} else {
				// List is empty
				iter.stamp = 0;
				return false;
			}
		}

		public bool iter_has_child (TreeIter iter) {
			// Again! It's a list model not a tree model. So, our
			// nodes have no children.
			return false;
		}

		public int iter_n_children (TreeIter? iter) {
			if (iter == null)	// handling the root node
				return this.size;
			if (iter.stamp != this.stamp) // invalid iter
				return -1;
			return 0;			// a list iter has no children
		}

		public bool iter_nth_child (out TreeIter iter, TreeIter? parent, int n) {
			if (parent != null || n > this.size) {
				iter.stamp = 0;
				return false;
			} else {
				Bookmark bookmark = ((BookmarkList) this).get (n);
				iter.stamp = this.stamp;
				iter.user_data = bookmark;
				return true;
			}
		}

		public bool iter_next (ref TreeIter iter) {
			int index;
			if (iter.stamp != this.stamp)
				return false;
			if (this.size < 2) {
				iter.stamp = 0;
				return false;
			}
			index = ((BookmarkList) this).index_of ((Bookmark) iter.user_data);
			if (index == -1 || index+2 > this.size) {
				iter.stamp = 0;
				return false;
			}
			Bookmark bookmark = ((BookmarkList) this).get (index+1);
			iter.user_data = bookmark;
			return true;
		}

		public bool iter_parent (out TreeIter iter, TreeIter child) {
			iter.stamp = 0;
			return false;
		}

		// These methods are not from any interface but are necessary
		public void insert_data (int position, Bookmark data) {
			var iter = TreeIter ();
			var path = new TreePath ();

			if (position > this.size)
				position = this.size;

			iter.stamp = this.stamp;
			iter.user_data = data;
			this.insert (position, data);

			path.append_index (position);
			this.row_inserted (path, iter);
		}

		public void append_data (Bookmark data) {
			this.insert_data (this.size, data);
		}

		public void remove_index (int index) {
			var path = new TreePath ();
			path.append_index (index);

			this.remove_at (index);
			this.row_deleted (path);
		}

		// Ignoring these methods as documentation allows to
		public void ref_node (TreeIter iter) {}
		public void unref_node (TreeIter iter) {}
	}
}
