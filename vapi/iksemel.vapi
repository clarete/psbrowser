/* iksemel.vapi - Vala bindings for iksemel
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


[CCode (cheader_filename="iksemel.h")]
namespace Iksemel {

	[Compact]
	[CCode (cname="ikstack", free_function="iks_stack_delete")]
	public class Stack {
		[CCode (cname="iks_stack_new")]
		public Stack (size_t meta_chunk, size_t data_chunk);
	}

	[Compact]
	[CCode (cname="iksid", free_function="")]
	public class Id {
		public string user;
		public string server;
		public string resource;
		public string partial;
		public string full;

		[CCode (cname="iks_id_new")]
		public Id (Stack stack, string jid);
	}

	[Compact]
	[CCode (cname="iks", free_function="iks_delete")]
	public class Iks {
		[CCode (cname="iks_new")]
		public Iks (string name);

		[CCode (cname="iks_insert")]
		public unowned Iks insert (string name);

		[CCode (cname="iks_insert_cdata")]
		public unowned Iks insert_cdata (string data, size_t len);

		[CCode (cname="iks_insert_attrib")]
		public unowned Iks insert_attrib (string name, string value);

		[CCode (cname="iks_insert_node")]
		public unowned Iks insert_node (Iks y);

		[CCode (cname="iks_append")]
		public unowned Iks append (string name);

		[CCode (cname="iks_prepend")]
		public unowned Iks prepend (string name);

		[CCode (cname="iks_append_cdata")]
		public unowned Iks append_cdata (string data, size_t len);

		[CCode (cname="iks_prepend_cdata")]
		public unowned Iks prepend_cdata (string data, size_t len);

		[CCode (cname="iks_next")]
		public unowned Iks next ();

		[CCode (cname="iks_next_tag")]
		public unowned Iks? next_tag ();

		[CCode (cname="iks_prev")]
		public unowned Iks? prev ();

		[CCode (cname="iks_prev_tag")]
		public unowned Iks prev_tag ();

		[CCode (cname="iks_parent")]
		public unowned Iks parent ();

		[CCode (cname="iks_root")]
		public unowned Iks root ();

		[CCode (cname="iks_child")]
		public unowned Iks child ();

		[CCode (cname="iks_first_tag")]
		public unowned Iks first_tag ();

		[CCode (cname="iks_attr")]
		public unowned Iks attr ();

		[CCode (cname="iks_find")]
		public unowned Iks? find (string name);

		[CCode (cname="iks_find_cdata")]
		public unowned string? find_cdata (string name);

		[CCode (cname="iks_find_attrib")]
		public unowned string? find_attrib (string name);

		[CCode (cname="iks_string")]
		private static unowned string _string (void *nil, Iks x);

		public unowned string to_string () {
			return _string (null, this);
		}
	}

	[CCode (cname="ikshowtype")]
	public enum ShowType {
		[CCode (cname="IKS_SHOW_UNAVAILABLE")]
		UNAVAILABLE,
		[CCode (cname="IKS_SHOW_AVAILABLE")]
		AVAILABLE,
		[CCode (cname="IKS_SHOW_CHAT")]
		CHAT,
		[CCode (cname="IKS_SHOW_AWAY")]
		AWAY,
		[CCode (cname="IKS_SHOW_XA")]
		XA,
		[CCode (cname="IKS_SHOW_DND")]
		DND
	}

	[CCode (cname="iks_make_pres")]
	public Iks make_pres (ShowType type, string status);
}
