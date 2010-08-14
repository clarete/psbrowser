/* node-new.vala - This file is part of the psbrowser program
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

public class PsBrowser.UI.NewNodeForm : Builder {
	Dialog dialog;

	public NewNodeForm (Window? parent) {
		try {
			this.add_from_file (
				Resources.get_resource_file ("data/newnode.ui"));
		} catch (Error e) {
			critical ("Unable to load ui definition file: %s", e.message);
		}
		this.dialog = (Dialog) this.get_object ("mainDialog");
		if (parent != null)
			this.dialog.set_transient_for (parent);
	}

	public void run () {
		dialog.run ();
	}

	public void destroy () {
		dialog.destroy ();
	}
}
