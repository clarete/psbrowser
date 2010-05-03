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
#include <errno.h>
#include <readline/readline.h>
#include <readline/history.h>
#include <iksemel.h>
#include <taningia/taningia.h>
#include <bitu/util.h>

#include "psbrowser.h"
#include "hashtable.h"
#include "hashtable-utils.h"

#define DEFAULT_PS1 "> "
#define VERSION     "0.1"

struct ps_command
{
  const char *name;
  const char *doc;
  int nparams;
  ps_callback_t callback;
};

struct ps_ctx
{
  ta_xmpp_client_t *xmpp;
  hashtable_t *commands;
  char *cwd;
  char *oldcwd;
  const char *from;
  const char *to;
};

static void read_command (ps_ctx_t *ctx);

static void *
xmalloc (size_t size)
{
  void *ret;
  while (size % 8 != 0)
    size++;
  if ((ret = malloc (size)) == NULL)
    {
      fprintf (stderr, "Couldn't alloc memory\n");
      exit (ENOMEM);
    }
  return ret;
}

static void *
xrealloc (void *ptr, size_t size)
{
  void *ret;
  while (size % 8 != 0)
    size++;
  if ((ret = realloc (ptr, size)) == NULL)
    {
      fprintf (stderr, "Couldn't alloc memory\n");
      if (ptr) free (ptr);
      exit (ENOMEM);
    }
  return ret;
}

/* generic answer parser callback */
static void
parse_answer (ta_xmpp_client_t *client, iks *node, void *data)
{
  ps_ctx_t *ctx = (ps_ctx_t *) data;

  /* Handling any possible error */
  if (strcmp (iks_find_attrib (node, "type"), "error") == 0)
    {
      /* Traversiong to iq > query > error and looking for the
       * `item-not-found' node. */
      iks *error = iks_find (node, "error");
      if (error)
        {
          char *err = iks_string (NULL, error);
          fprintf (stderr, "%s\n", err);
        }
    }
  read_command (ctx);
}

/* commands */

static void
parse_list (ta_xmpp_client_t *client, iks *node, void *data)
{
  iks *item;
  ps_ctx_t *ctx = (ps_ctx_t *) data;

  /* Handling any possible error */
  if (strcmp (iks_find_attrib (node, "type"), "error") == 0)
    {
      /* Traversiong to iq > query > error and looking for the
       * `item-not-found' node. */
      if (iks_find (iks_find (node, "error"), "item-not-found"))
        fprintf (stderr, "Node not found\n");
      goto end;
    }

  /* Traversing to iq > query and then iterating over its (item)
   * childs. */
  item = iks_child (iks_find (node, "query"));
  while (item)
    {
      char *node = iks_find_attrib (item, "node");
      if (node)
        printf ("%s\n", node);
      item = iks_next (item);
    }

 end:
  read_command (ctx);
}

static void
cmd_list (ps_ctx_t *ctx, ps_command_t *cmd, char **params,
          int nparams, void *data)
{
  char *name = NULL;
  iks *info;

  if (nparams == 1)
    {
      size_t len;
      name = strdup (params[0]);

      /* Getting rid of trailing "/" chars at the end of the node name
       * parameter */
      len = strlen (name) - 1;
      while (name[len] == '/')
        name[len--] = '\0';
    }
  else if (nparams == 0 && ctx->cwd != NULL)
    name = strdup (ctx->cwd);
  else
    ctx->cwd = NULL;

  info = ta_pubsub_node_query_nodes (ctx->from, ctx->to, name);
  ta_xmpp_client_send_and_filter (ctx->xmpp, info, parse_list, ctx, NULL);
  iks_delete (info);
}

static void
cmd_mkdir (ps_ctx_t *ctx, ps_command_t *cmd, char **params,
           int nparams, void *data)
{
  iks *iq;
  iq = ta_pubsub_node_create (ctx->from, ctx->to, params[0],
                              "type", "collection", NULL);
  ta_xmpp_client_send_and_filter (ctx->xmpp, iq, parse_answer, ctx, NULL);
  iks_delete (iq);
}

static void
cmd_delete (ps_ctx_t *ctx, ps_command_t *cmd, char **params,
            int nparams, void *data)
{
  iks *iq;
  iq = ta_pubsub_node_delete (ctx->from, ctx->to, params[0]);
  ta_xmpp_client_send_and_filter (ctx->xmpp, iq, parse_answer, ctx, NULL);
  iks_delete (iq);
}

static void
cmd_subscribe (ps_ctx_t *ctx, ps_command_t *cmd, char **params,
               int nparams, void *data)
{
  iks *iq;
  char *node, *jid;
  node = params[0];
  if (nparams == 1)
    jid = (char *) ctx->from;
  else if (nparams == 2)
    jid = params[1];
  iq = ta_pubsub_node_subscribe (ctx->from, ctx->to, node, jid);
  ta_xmpp_client_send_and_filter (ctx->xmpp, iq, parse_answer, ctx, NULL);
  iks_delete (iq);
}

static void
cmd_unsubscribe (ps_ctx_t *ctx, ps_command_t *cmd, char **params,
                 int nparams, void *data)
{
  iks *iq;
  char *node, *jid;
  node = params[0];
  if (nparams == 1)
    jid = (char *) ctx->from;
  else if (nparams == 2)
    jid = params[1];
  iq = ta_pubsub_node_unsubscribe (ctx->from, ctx->to, node, jid);
  ta_xmpp_client_send_and_filter (ctx->xmpp, iq, parse_answer, ctx, NULL);
  iks_delete (iq);
}

static void
parse_subscriptions (ta_xmpp_client_t *client, iks *node, void *data)
{
  iks *item;
  ps_ctx_t *ctx = (ps_ctx_t *) data;

  /* Handling any possible error */
  if (strcmp (iks_find_attrib (node, "type"), "error") == 0)
    {
      /* Traversiong to iq > query > error and looking for the
       * `item-not-found' node. */
      if (iks_find (iks_find (node, "error"), "item-not-found"))
        fprintf (stderr, "Node not found\n");
      goto end;
    }

  /* Traversing to iq > pubsub > subscriptions > subscription and then
   * iterating over its (item) siblings. */
  item = iks_child (iks_child (iks_child (node)));
  while (item)
    {
      printf ("%s (%s)\n",
              iks_find_attrib (item, "jid"),
              iks_find_attrib (item, "subscription"));
      item = iks_next (item);
    }
 end:
  read_command (ctx);
}

static void
cmd_subscriptions (ps_ctx_t *ctx, ps_command_t *cmd, char **params,
                   int nparams, void *data)
{
  iks *iq;
  char *node;
  node = params[0];
  iq = ta_pubsub_node_query_subscriptions (ctx->from, ctx->to, node);
  ta_xmpp_client_send_and_filter (ctx->xmpp, iq, parse_subscriptions,
                                  ctx, NULL);
  iks_delete (iq);
}

static void
parse_affiliations (ta_xmpp_client_t *client, iks *node, void *data)
{
  iks *item;
  ps_ctx_t *ctx = (ps_ctx_t *) data;

  /* Handling any possible error */
  if (strcmp (iks_find_attrib (node, "type"), "error") == 0)
    {
      /* Traversiong to iq > query > error and looking for the
       * `item-not-found' node. */
      if (iks_find (iks_find (node, "error"), "item-not-found"))
        fprintf (stderr, "Node not found\n");
      goto end;
    }

  /* Traversing to iq > pubsub > subscriptions > subscription and then
   * iterating over its (item) siblings. */
  item = iks_child (iks_child (iks_child (node)));
  while (item)
    {
      printf ("%s (%s)\n",
              iks_find_attrib (item, "node"),
              iks_find_attrib (item, "affiliation"));
      item = iks_next (item);
    }
 end:
  read_command (ctx);
}

static void
cmd_affiliations (ps_ctx_t *ctx, ps_command_t *cmd, char **params,
                  int nparams, void *data)
{
  iks *iq;
  iq = ta_pubsub_query_affiliations (ctx->from, ctx->to);
  ta_xmpp_client_send_and_filter (ctx->xmpp, iq, parse_affiliations, ctx,
                                  NULL);
  iks_delete (iq);
}

static void
parse_cd_query (ta_xmpp_client_t *client, iks *node, void *data)
{
  ps_ctx_t *ctx = (ps_ctx_t *) data;
  if (strcmp (iks_find_attrib (node, "type"), "error") == 0)
    {
      /* Telling the bad news */
      printf ("Node `%s' not found\n", ctx->cwd);

      /* Rolling back the current directory change */
      free (ctx->cwd);
      ctx->cwd = ctx->oldcwd;
      ctx->oldcwd = NULL;
    }
  read_command (ctx);
}

/* This command basically controlls the ctx->cwd variable
 * content. This var will be used by the `cmd_list()' to be the base
 * directory when listing some node content. */
static void
cmd_cd (ps_ctx_t *ctx, ps_command_t *cmd, char **params,
        int nparams, void *data)
{
  iks *query_nodes;
  size_t len;

  if (ctx->cwd != NULL)
    {
      /* Caching current value of cwd (don't need to free it) */
      if (ctx->oldcwd)
        free (ctx->oldcwd);
      ctx->oldcwd = ctx->cwd;
      ctx->cwd = NULL;
    }
  if (nparams == 0)
    {
      /* No verification is needed. It is obvious that the `no node
       * selected' node exists =P */
      ctx->cwd = NULL;
      read_command (ctx);
      return;
    }

  ctx->cwd = strdup (params[0]);

  /* Getting rid of the anoying trailing slash */
  len = strlen (ctx->cwd) - 1;
  while (ctx->cwd[len] == '/')
    ctx->cwd[len--] = '\0';

  /* This is a good time to validate if the `directory' choosen
   * actually exists. */
  query_nodes = ta_pubsub_node_query_nodes (ctx->from, ctx->to, ctx->cwd);
  ta_xmpp_client_send_and_filter (ctx->xmpp, query_nodes, parse_cd_query,
                                  ctx, NULL);
  iks_delete (query_nodes);
}

static void
cmd_pwd (ps_ctx_t *ctx, ps_command_t *cmd, char **params,
         int nparams, void *data)
{
  if (ctx->cwd != NULL)
    printf ("%s\n", ctx->cwd);
  else
    printf ("<root>\n");
  read_command (ctx);
}

static void
cmd_help (ps_ctx_t *ctx, ps_command_t *cmd, char **params,
          int nparams, void *data)
{
  void *iter;
  printf ("PsBrowser v" VERSION ", available commands:\n");
  iter = hashtable_iter (ctx->commands);
  while (iter)
    {
      printf (" %-16s : %s\n",
              (char *) hashtable_iter_key (iter),
              ((ps_command_t *) hashtable_iter_value (iter))->doc);
      iter = hashtable_iter_next (ctx->commands, iter);
    }
  read_command (ctx);
}


/* little helper function to generate a pretty PS1 like value to feed
 * the readline() call. */

static char *
gen_ps1 (ps_ctx_t *ctx)
{
  char *ps1 = NULL;
  size_t len, total;

  /* Initial size */
  total = len = strlen (ctx->from);

  /* This +3 reserve space to the `> \0' last chars */
  ps1 = xmalloc (len+3);
  memcpy (ps1, ctx->from, len);
  ps1[len++] = ':';

  if (ctx->cwd)
    {
      char *p, *s, *tmp;
      /* Saving current end of string */
      total = len + strlen (ctx->cwd);
      tmp = xrealloc (ps1, total + 3);
      ps1 = tmp;
      s = ps1 + len;
      p = ctx->cwd;
      for (; *p != '\0'; *s++ = *p++);
    }

  ps1[total++] = '>';
  ps1[total++] = ' ';
  ps1[total] = '\0';
  return ps1;
}

/* function that reads a new command form the shell */

static void
read_command (ps_ctx_t *ctx)
{
  char *ps1 = NULL;
  char *line;
  size_t llen;

  /* Vars used to parse command line */
  char *cmd = NULL;
  char **params = NULL;
  int nparams;

  /* Every shell needs to have a pretty PS1 */
  if ((ps1 = gen_ps1 (ctx)) == NULL)
    ps1 = strdup (DEFAULT_PS1);

  /* Main readline call.*/
  line = readline (ps1);
  free (ps1);

  if (line == NULL)
    {
      printf ("\n");
      exit (EXIT_SUCCESS);
      return;
    }
  if ((llen = strlen (line)) == 0)
    read_command (ctx);

  /* Saving readline history */
  add_history (line);

  if (!bitu_util_extract_params (line, &cmd, &params, &nparams))
    return;
  else
    {
      ps_command_t *command;
      if ((command = hashtable_get (ctx->commands, cmd)) == NULL)
        {
          printf ("Command `%s' not found\n", cmd);
          read_command (ctx);
          return;
        }
      if (command->nparams > nparams)
        {
          printf ("Command `%s' takes at least %d params. (%d given)\n",
                  cmd, command->nparams, nparams);
          read_command (ctx);
          return;
        }
      command->callback (ctx, command, params, nparams, NULL);
    }
}

/* taningia xmpp client event callbacks */

static int
auth_cb (ta_xmpp_client_t *client, iks *pak, void *data)
{
  iks *node;
  ps_ctx_t *ctx = (ps_ctx_t *) data;

  /* Sending presence info */
  node = iks_make_pres (IKS_SHOW_AVAILABLE, "Online");
  ta_xmpp_client_send (client, node);
  iks_delete (node);

  /* Starting reading the first command */
  read_command (ctx);
  return 0;
}

static int
auth_failed_cb (ta_xmpp_client_t *client, iks *pak, void *data)
{
  printf ("Authentication failed. Username or password are wrong\n");
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

static char *
get_history_file ()
{
  char *home;
  char hist_file[256];
  home = getenv ("HOME");
  if (home == NULL)
    home = "~";
  snprintf (hist_file, 256, "%s/.psbrowserhistory", home);
  return strdup (hist_file);
}

static void
save_history_file (void)
{
  char *hfile = get_history_file ();
  write_history (hfile);
  free (hfile);
}

static inline void
_register_cmd (ps_ctx_t *ctx, const char *name, const char *doc, int nparams,
               ps_callback_t cb)
{
  ps_command_t *cmd;
  cmd = xmalloc (sizeof (ps_command_t));
  cmd->name = name;
  cmd->doc = doc;
  cmd->nparams = nparams;
  cmd->callback = cb;
  hashtable_set (ctx->commands, (void *) name, cmd);
}

static void
ps_ctx_register_commands (ps_ctx_t *ctx)
{
  _register_cmd (ctx, "help", "Lists all available commands", 0, cmd_help);
  _register_cmd (ctx, "ls", "Lists nodes in a sub node", 0, cmd_list);
  _register_cmd (ctx, "cd", "Changes the working node", 0, cmd_cd);
  _register_cmd (ctx, "pwd", "Shows wich node is selected", 0, cmd_pwd);
  _register_cmd (ctx, "rm", "Removes a node", 1, cmd_delete);
  _register_cmd (ctx, "mkdir", "Creates a collection node", 1, cmd_mkdir);
  _register_cmd (ctx, "subscribe", "Subscribes the connected JID to a node", 1,
                 cmd_subscribe);
  _register_cmd (ctx, "unsubscribe",
                 "Unsubscribes the connected JID from a node", 1,
                 cmd_unsubscribe);
  _register_cmd (ctx, "subscriptions", "List all JID's subscripted to a node",
                 1, cmd_subscriptions);
  _register_cmd (ctx, "affiliations", "Lists all nodes that the loged user "
                 "is affiliated to and the affiliation type", 0,
                 cmd_affiliations);
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
  char *hfile = NULL;

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

  /* Initializing the app context */
  ctx = xmalloc (sizeof (ps_ctx_t));
  ctx->xmpp = ta_xmpp_client_new (jid, password, addr, port);
  ctx->cwd = NULL;
  ctx->oldcwd = NULL;
  ctx->from = jid;
  ctx->to = service;
  ctx->commands = hashtable_create (hash_string, string_equal, NULL, free);
  ps_ctx_register_commands (ctx);
  logger = ta_xmpp_client_get_logger (ctx->xmpp);
  ta_log_set_use_colors (logger, 1);
  ta_log_set_level (logger, TA_LOG_WARN);

  /* Initializing history library and registering a callback to write
   * back to history file when program finishes. */
  hfile = get_history_file ();
  using_history ();
  read_history (hfile);
  atexit (save_history_file);
  free (hfile);

  ta_xmpp_client_event_connect (ctx->xmpp, "authenticated",
                                (ta_xmpp_client_hook_t) auth_cb,
                                ctx);

  ta_xmpp_client_event_connect (ctx->xmpp, "authentication-failed",
                                (ta_xmpp_client_hook_t) auth_failed_cb,
                                NULL);

  /* Connecting and running xmpp client */
  if (!ta_xmpp_client_connect (ctx->xmpp))
    {
      ta_error_t *error;
      error = ta_xmpp_client_get_error (ctx->xmpp);
      fprintf (stderr, "%s: %s\n", ta_error_get_name (error),
               ta_error_get_message (error));
      ta_object_unref (error);
      goto finalize;
    }
  if (!ta_xmpp_client_run (ctx->xmpp, 0))
    {
      ta_error_t *error;
      error = ta_xmpp_client_get_error (ctx->xmpp);
      fprintf (stderr, "%s: %s\n", ta_error_get_name (error),
               ta_error_get_message (error));
      ta_object_unref (error);
      goto finalize;
    }
  return 0;

  /* Things went bad when setting up the XMPP client, let's free
   * allocated stuff and get out with an error. */
 finalize:
  ta_object_unref (ctx->xmpp);
  hashtable_destroy (ctx->commands);
  free (ctx);
  return 1;
}
