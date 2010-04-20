/* main.c - This file is part of the psbrowser program
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <readline/readline.h>
#include <readline/history.h>
#include <iksemel.h>
#include <taningia/taningia.h>
#include <bitu/util.h>

#include "psbrowser.h"
#include "hashtable.h"
#include "hashtable-utils.h"

#define PS1    "> "

struct ps_command
{
  const char *name;
  int nparams;
  ps_callback_t callback;
};

struct ps_ctx
{
  ta_xmpp_client_t *xmpp;
  hashtable_t *commands;
  const char *from;
  const char *to;
};

int command_running = 0;

/* commands */

static void
parse_list (ta_xmpp_client_t *client, iks *node, void *data)
{
  iks *item;

  /* Handling any possible error */
  if (strcmp (iks_find_attrib (node, "type"), "error") == 0)
    {
      /* Traversiong to iq > query > error and looking for the
       * `item-not-found' node. */
      if (iks_find (iks_find (node, "error"), "item-not-found"))
        printf ("Node `%s' not found\n", (char *) data);
      command_running = 0;
      return;
    }

  /* Traversing to iq > query and then iterating over its (item)
   * childs. */
  item = iks_child (iks_find (node, "query"));
  while (item)
    {
      printf ("%s\n", iks_find_attrib (item, "node"));
      item = iks_next (item);
    }

  command_running = 0;
}

static char *
cmd_list (ps_ctx_t *ctx, ps_command_t *cmd, char **params,
          int nparams, void *data)
{
  char *name = NULL;
  char *ret = NULL;
  iks *info;

  if (nparams == 1)
    name = strdup (params[0]);
  info = ta_pubsub_node_query_nodes (ctx->from, ctx->to, name);
  ta_xmpp_client_send_and_filter (ctx->xmpp, info, parse_list, name, free);
  iks_delete (info);
  command_running = 1;
  return ret;
}

static char *
cmd_mkdir (ps_ctx_t *ctx, ps_command_t *cmd, char **params,
           int nparams, void *data)
{
  char *ret = NULL;
  iks *iq;
  iq = ta_pubsub_node_create (ctx->from, ctx->to, params[0],
                              "type", "collection", NULL);
  ta_xmpp_client_send (ctx->xmpp, iq);
  iks_delete (iq);
  return ret;
}

static char *
cmd_delete (ps_ctx_t *ctx, ps_command_t *cmd, char **params,
            int nparams, void *data)
{
  char *ret = NULL;
  iks *iq;
  iq = ta_pubsub_node_delete (ctx->from, ctx->to, params[0]);
  ta_xmpp_client_send (ctx->xmpp, iq);
  iks_delete (iq);
  return ret;
}

/* taningia xmpp client event callbacks */

static int
auth_cb (ta_xmpp_client_t *client, void *data)
{
  iks *node;

  /* Sending presence info */
  node = iks_make_pres (IKS_SHOW_AVAILABLE, "Online");
  ta_xmpp_client_send (client, node);
  iks_delete (node);

  /* executing requested command */

  return 0;
}

static int
auth_failed_cb (ta_xmpp_client_t *client, void *data)
{
  ta_xmpp_client_disconnect (client);
  return 0;
}

static void
usage (const char *pname)
{
  fprintf (stderr,
           "Usage: %s [OPTIONS]\n\n"
           "Options:\n"
           "  -j <jid>\n"
           "  -p <password>\n"
           "  -s <pubsub-service>\n"
           "  -a <server-addr>\n",
           pname);
}

static inline void
_register_cmd (ps_ctx_t *ctx, const char *name, int nparams, ps_callback_t cb)
{
  ps_command_t *cmd;
  cmd = malloc (sizeof (ps_command_t));
  cmd->name = name;
  cmd->nparams = nparams;
  cmd->callback = cb;
  hashtable_set (ctx->commands, (void *) name, cmd);
}

static void
ps_ctx_register_commands (ps_ctx_t *ctx)
{
  _register_cmd (ctx, "ls", 0, cmd_list);
  _register_cmd (ctx, "rm", 1, cmd_delete);
  _register_cmd (ctx, "mkdir", 1, cmd_mkdir);
}

int
main (int argc, char **argv)
{
  int opt;
  char *jid = NULL,
    *password = NULL,
    *service = NULL,
    *addr = NULL;
  int port = 5222;
  ps_ctx_t *ctx;
  ta_log_t *logger;

  while ((opt = getopt (argc, argv, "j:p:s:a:")) != -1)
    {
      switch (opt)
        {
        case 'j':
          jid = optarg;
          break;

        case 'p':
          password = optarg;
          break;

        case 's':
          service = optarg;
          break;

        case 'a':
          addr = optarg;
          break;

        default:
          usage (argv[0]);
          exit (EXIT_FAILURE);
        }
    }
  if (!jid || !password || !service || !addr)
    {
      usage (argv[0]);
      exit (EXIT_FAILURE);
    }

  ctx = malloc (sizeof (ps_ctx_t));
  ctx->xmpp = ta_xmpp_client_new (jid, password, addr, port);

  ta_xmpp_client_event_connect (ctx->xmpp, "authenticated",
                                (ta_xmpp_client_hook_t) auth_cb,
                                NULL);

  ta_xmpp_client_event_connect (ctx->xmpp, "authentication-failed",
                                (ta_xmpp_client_hook_t) auth_failed_cb,
                                NULL);

  logger = ta_xmpp_client_get_logger (ctx->xmpp);
  ta_log_set_use_colors (logger, 1);
  ta_log_set_level (logger, TA_LOG_WARN);

  ctx->from = jid;
  ctx->to = service;
  ctx->commands = hashtable_create (hash_string, string_equal, NULL, free);
  ps_ctx_register_commands (ctx);

  if (!ta_xmpp_client_connect (ctx->xmpp))
    {
      ta_error_t *error;
      error = ta_xmpp_client_get_error (ctx->xmpp);
      fprintf (stderr, "%s: %s\n", ta_error_get_name (error),
               ta_error_get_message (error));
      ta_object_unref (error);
      goto finalize;
    }
  if (!ta_xmpp_client_run (ctx->xmpp, 1))
    {
      ta_error_t *error;
      error = ta_xmpp_client_get_error (ctx->xmpp);
      fprintf (stderr, "%s: %s\n", ta_error_get_name (error),
               ta_error_get_message (error));
      ta_object_unref (error);
      goto finalize;
    }

  while (1)
    {
      char *line;
      size_t llen;

      /* Vars used to parse command line */
      char *cmd = NULL;
      char **params = NULL;
      int nparams;

      /* Main readline call.*/
      line = readline (PS1);

      if (line == NULL)
        {
          printf ("\n");
          break;
        }
      if ((llen = strlen (line)) == 0)
        continue;
      if (!bitu_util_extract_params (line, &cmd, &params, &nparams))
        continue;
      else
        {
          ps_command_t *command;
          char *msg;
          if ((command = hashtable_get (ctx->commands, cmd)) == NULL)
            {
              printf ("Command `%s' not found\n", cmd);
              continue;
            }
          if (command->nparams > nparams)
            {
              printf ("Command `%s' takes at least %d params. (%d given)\n",
                      cmd, command->nparams, nparams);
              continue;
            }
          if ((msg = command->callback (ctx, command, params, nparams, NULL))
              != NULL)
            {
              printf ("%s", msg);
              free (msg);
            }
        }

      /* A little (hammer) timeout to wait the command to run. If the
       * server does not answer, we'll not leave this loop and it is
       * not good. */
      while (command_running)
        sleep (0.5);
    }

 finalize:
  ta_object_unref (ctx->xmpp);
  hashtable_destroy (ctx->commands);
  free (ctx);

  return 0;
}
