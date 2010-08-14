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

using Gee;
using Gtk;
using Iksemel;
using Taningia;

/** New node form */
public class PsBrowser.UI.NewNodeForm : Builder {
	Dialog dialog;

	public NewNodeForm (Window? parent) {
		/* Loading (or trying to load) the resource that contains the
		 * UI definition */
		try {
			this.add_from_file (
				Resources.get_resource_file ("data/newnode.ui"));
		} catch (Error e) {
			critical ("Unable to load ui definition file: %s", e.message);
		}

		/* Setting up the main dialog var */
		this.dialog = (Dialog) this.get_object ("mainDialog");
		if (parent != null)
			this.dialog.set_transient_for (parent);

		/* Setting default values for "When to send the last published
		 * item" radio buttons */
		((RadioButton) this.get_object ("send_last_published_item2"))
			.set_active (true);

		/* Connecting signals declared in glade to this context */
		this.connect_signals (this);
	}

	/** Calls the dialog.run () method and builds a pubsub node with
	 * data extracted from the form filled by the user.
	 *
	 * @param from Is the JID that is requesting the node creation.
	 * @param to Is the pubsub service JID
	 */
	public Iks? get_node (string from, string to) {
		if (dialog.run () == 1) {
			/* User pressed "OK" */

			/* Array to hold configuration entries */
			var aparams = new Gee.ArrayList<string> ();

			/* Getting config parameters from the user interface */

			/* -- node name */
			var node_name = ((Entry) this.get_object ("nodeName")).text;

			/* -- title */
			var title = ((Entry) this.get_object ("title")).text;
			if (title.length > 0) {
				aparams.add ("title");
				aparams.add (title);
			}

			/* -- node_type */
			aparams.add ("node_type");
			if (((RadioButton) this.get_object ("rbTypeCollection")).active)
				aparams.add ("collection");
			else
				aparams.add ("leaf");

			/* -- publish model */
			var combo = ((ComboBox) this.get_object ("publish_model"));
			aparams.add ("publish_model");
			aparams.add (combo.get_active_text ());

			/* -- subscribe */
			aparams.add ("subscribe");
			if (((ToggleButton) this.get_object ("subscribe")).active)
				aparams.add ("1");
			else
				aparams.add ("0");

			/* -- access model */
			var combo1 = ((ComboBox) this.get_object ("access_model"));
			aparams.add ("access_model");
			aparams.add (combo1.get_active_text ());

			/* -- TODO: roster_groups_allowed */

			/* -- persist_items */
			aparams.add ("persist_items");
			if (((ToggleButton) this.get_object ("persist_items")).active)
				aparams.add ("1");
			else
				aparams.add ("0");

			/** -- deliver_payloads */
			aparams.add ("deliver_payloads");
			if (((ToggleButton) this.get_object ("deliver_payloads")).active)
				aparams.add ("1");
			else
				aparams.add ("0");

			/* -- max_items */
			var max_items_bt = (SpinButton) this.get_object ("max_items");
			var max_items = max_items_bt.get_value_as_int ();
			if (max_items > 0) {
				aparams.add ("max_items");
				aparams.add (@"$max_items");
			}

			/* -- max_payload_size */
			var max_payload_size_bt =
				(SpinButton) this.get_object ("max_payload_size");
			var max_payload_size = max_payload_size_bt.get_value_as_int ();
			if (max_payload_size > 0) {
				aparams.add ("max_payload_size");
				aparams.add (@"$max_payload_size");
			}

			/* -- type */
			var type = ((Entry) this.get_object ("type")).text;
			if (type.length > 0) {
				aparams.add ("type");
				aparams.add (type);
			}

			/* -- deliver_notifications */
			var field =
				(ToggleButton) this.get_object ("deliver_notifications");
			aparams.add ("deliver_notifications");
			if (field.active)
				aparams.add ("1");
			else
				aparams.add ("0");

			/* -- presence_based_delivery */
			var field1 =
				(ToggleButton) this.get_object ("presence_based_delivery");
			aparams.add ("presence_based_delivery");
			if (field1.active)
				aparams.add ("1");
 			else
				aparams.add ("0");

			/* -- notify_config */
			aparams.add ("notify_config");
			if (((ToggleButton) this.get_object ("notify_config")).active)
				aparams.add ("1");
			else
				aparams.add ("0");

			/* -- notify_delete */
			aparams.add ("notify_delete");
			if (((ToggleButton) this.get_object ("notify_delete")).active)
				aparams.add ("1");
			else
				aparams.add ("0");
 
			/* -- notify_retract */
			aparams.add ("notify_retract");
			if (((ToggleButton) this.get_object ("notify_retract")).active)
				aparams.add ("1");
			else
				aparams.add ("0");

			/* -- notify_sub */
			aparams.add ("notify_sub");
			if (((ToggleButton) this.get_object ("notify_sub")).active)
				aparams.add ("1");
			else
				aparams.add ("0");

			/* -- send_last_published_item */
			aparams.add ("send_last_published_item");
			if (((RadioButton)
				 this.get_object ("send_last_published_item")).active)
				aparams.add ("never");
			else if (((RadioButton)
					  this.get_object ("send_last_published_item1")).active)
				aparams.add ("on_sub");
			else if (((RadioButton)
					  this.get_object ("send_last_published_item2")).active)
				aparams.add ("on_sub_and_presence");

			/* Finally creating and returning the node */
			var node = Pubsub.node_createv (
				from, to, node_name, aparams.to_array ());
			return node;
		} else {
			/* User cancelled the operation */
			return null;
		}
	}

	/** Calls the dialog destructor method */
	public void destroy () {
		dialog.destroy ();
	}

	/** Validates the content of all important fields in the new
	 * bookmark form and set the ok button sensitivity depending on
	 * the validation result. */
	[CCode (instance_pos=-1)]
	public void validate (Entry editable) {
		bool sensitive = editable.get_text ().length > 0;
		((Widget) this.get_object ("btOk")).set_sensitive (sensitive);
	}
}
