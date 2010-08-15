/* taningia.vapi - Vala bindings for taningia
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

using Iksemel;

[CCode (cheader_filename="taningia/taningia.h")]
namespace Taningia {

	[CCode (cname="ta_free_func_t", has_target=false)]
	public delegate void FreeFunc (void* user_data);

	[CCode (cname="ta_log_handler_func_t", has_target=false)]
	public delegate int LogHandlerFunc (Log log, LogLevel level,
										string msg, void *data);

	[CCode (cname="ta_log_level_t", has_type_id="0", cprefix="TA_LOG_")]
	public enum LogLevel {
		DEBUG,
		INFO,
		WARN,
		ERROR,
		CRITICAL
	}

	[Compact]
	[CCode (cname="ta_log_t",
			ref_function="ta_object_ref",
			unref_function="ta_object_unref",
			cprefix="ta_log_")]
	public class Log {
		public Log (string domain);
		public void set_use_colors (bool use_colors);
		public bool get_use_colors ();
		public void set_level (LogLevel level);
		public LogLevel get_level ();
		public void set_handler (LogHandlerFunc handler, void *data);
		public void info (string fmt);
		public void warn  (string fmt);
		public void debug (string fmt);
		public void error (string fmt);
		public void critical (string fmt);
	}

	namespace Xmpp {
		[CCode (cname="ta_xmpp_client_hook_t", has_target=false)]
		public delegate int ClientHookFunc (Client client, void *data1,
											void *data2);

		[CCode (cname="ta_xmpp_client_answer_cb_t", has_target=false)]
		public delegate int ClientAnswerCb (Client client, Iks node,
											void *data);

		[Compact]
		[CCode (cname="ta_xmpp_client_t",
				ref_function="ta_object_ref",
				unref_function="ta_object_unref",
				cprefix="ta_xmpp_client_",
				construct_function="ta_xmpp_client_new")]
		public class Client {
			public Client (string jid, string password,
						   string host, int port);
			public unowned string get_jid ();
			public unowned string get_password ();
			public unowned string get_host ();
			public int get_port ();
			public unowned void set_jid (string jid);
			public unowned void set_password (string password);
			public unowned void set_host (string host);
			public void set_port (int port);
			public unowned Log get_logger ();
			public int connect ();
			public int disconnect ();
			public int send (Iks node);
			public int send_and_filter (Iks node, ClientAnswerCb cb, void *data,
				FreeFunc? free_cb=null);
			public int run (bool detach);
			public bool is_running ();
			public int event_connect (string event, ClientHookFunc hook,
									  void *data);
		}
	}

	namespace Pubsub {
		[CCode (cname="ta_pubsub_node_query_nodes")]
		public Iks node_query_nodes (string from, string to, string? node);

		[CCode (cname="ta_pubsub_node_createv")]
		public Iks node_createv (
			string from, string to, string node,
			[CCode (array_length=false)] string[] conf_params);

		[CCode (cname="ta_pubsub_node_items")]
		public Iks node_items (string from, string to, string node,
							   int max_items=0);

		[CCode (cname="ta_pubsub_node_delete")]
		public Iks node_delete (string from, string to, string node);
	}
}
