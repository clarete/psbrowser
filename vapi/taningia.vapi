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

[CCode (cheader_filename="taningia/taningia.h")]
namespace Taningia {

	[CCode (cname="ta_log_handler_func_t")]
	public delegate int LogHandlerFunc (Log log, LogLevel level,
										string msg, void *data);

	[CCode (cname="ta_log_level_t", has_type_id="0")]
	public enum LogLevel {
		[CCode (cname="TA_LOG_DEBUG")]
		DEBUG,

		[CCode (cname="TA_LOG_INFO")]
		INFO,

		[CCode (cname="TA_LOG_WARN")]
		WARN,

		[CCode (cname="TA_LOG_ERROR")]
		ERROR,

		[CCode (cname="TA_LOG_CRITICAL")]
		CRITICAL
	}

	[Compact]
	[CCode (cname="ta_log_t", free_function="ta_object_unref")]
	public class Log {
		[CCode (cname = "ta_log_new")]
		public Log (string domain);

		[CCode (cname="ta_log_set_use_colors")]
		public void set_use_colors (bool use_colors);

		[CCode (cname="ta_log_get_use_colors")]
		public bool get_use_colors ();

		[CCode (cname="ta_log_set_level")]
		public void set_level (LogLevel level);

		[CCode (cname="ta_log_get_level")]
		public LogLevel get_level ();

		[CCode (cname="ta_log_set_handler")]
		public void set_handler (LogHandlerFunc handler, void *data);

		[CCode (cname="ta_log_info")]
		public void info (string fmt);

		[CCode (cname="ta_log_warn")]
		public void warn  (string fmt);

		[CCode (cname="ta_log_debug")]
		public void debug (string fmt);

		[CCode (cname="ta_log_error")]
		public void error (string fmt);

		[CCode (cname="ta_log_critical")]
		public void critical (string fmt);
	}
}
