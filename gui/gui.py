#!/usr/bin/env python
# -*- Coding: utf-8; -*-
#
# Copyright (C) 2010  Lincoln de Sousa <lincoln@comum.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

"""PsBrowser stands to Pubsub browser.

This program aims to be a generic viewer of pubsub nodes in a service
running on top of an XMPP server. We are using taningia[0] library
that provides an easy to use XMPP/Pubsub API.
"""

import gtk
import gobject
import taningia

gobject.threads_init()

class Loading(gtk.Image):
    """An abstraction for a loading widget that is shown when some
    async job is running. You can use the .{un,}ref_loading() methods
    to ask for showing or hidding it.
    """

    def __init__(self):
        super(Loading, self).__init__()

        # Loading flag. Call self.{ref,unref}_loading to manage it,
        # don't do it directly.
        self._is_loading = 0
        self.set_from_file('data/pixmaps/loading.gif')

    def _handle_loading(self):
        """Changes the visibility property of our `loading' image
        based on the `self.is_loading' flag. This is important because
        more than one action can request to show/hide it at the same
        time.
        """
        self.set_visible(self._is_loading > 0)

    def ref_loading(self):
        """Increment the loading request and call the loading
        show/hide function.
        """
        self._is_loading += 1
        self._handle_loading()

    def unref_loading(self):
        """Decrement the loading request and call the loading
        show/hide function.
        """
        self._is_loading = max(0, self._is_loading - 1)
        self._handle_loading()

class MainWindow(gtk.Builder):
    def __init__(self, ctx):
        super(MainWindow, self).__init__()
        self.add_from_file('psbrowser.ui')

        # Logging setup
        self.logger = taningia.log.Log('pypsbrowser')
        self.logger.set_level(taningia.log.TA_LOG_DEBUG)
        self.logger.set_use_colors(True)

        # Some important widgets
        self.mwin = self.get_object('mainWindow')
        self.treeview = self.get_object('treeview')
        self.treeviewp = self.get_object('treeviewPosts')
        self.setup_treeviews()
        self.loading = Loading()
        self.get_object('hboxTop').pack_end(self.loading, 0, 0, 0)

        # Setting up xmpp stuff
        self.jid_from = ctx.get('jid')
        self.jid_to = ctx.get('pservice')
        self.xmpp = taningia.xmpp.Client(
            ctx.get('jid'), ctx.get('password'),
            ctx.get('host'), ctx.get('port'))
        self.xmpp.event_connect('authenticated', self.auth_cb)
        self.xmpp.event_connect('authentication-failed', self.auth_failed_cb)
        self.xmpp.get_logger().set_level(taningia.log.TA_LOG_DEBUG)
        self.xmpp.get_logger().set_use_colors(True)

        # Setting up some ui stuff
        eventbox = self.get_object('titleEventbox')
        eventbox.modify_bg(gtk.STATE_NORMAL,
                           eventbox.get_colormap().alloc_color("#ffffff"))

        # Setting up signals
        self.mwin.connect('delete-event', self.quit)
        self.get_object('tbRefresh').connect('clicked', self.refresh_cb)

    def setup_treeviews(self):
        """Sets up renderers and columns for both node and post
        treeviews.
        """
        # node tree setup
        renderer = gtk.CellRendererText()
        column = gtk.TreeViewColumn('Node', renderer, text=0)
        self.treeview.append_column(column)
        self.treeview.connect('row-activated', self.list_posts)

        # post tree setup
        renderer = gtk.CellRendererText()
        column = gtk.TreeViewColumn('Post', renderer, text=0)
        self.treeviewp.append_column(column)

    def quit(self, *nil):
        """Disconnects the xmpp client from the server and quit the
        GUI main loop.
        """
        self.xmpp.disconnect()
        gtk.main_quit()

    def run(self):
        """Shows the main window, connect and start the xmpp client
        and then starts the GUI main loop.
        """
        self.mwin.show_all()
        self.xmpp.connect()
        self.xmpp.run(True)
        self.loading.ref_loading()
        gtk.main()

    # Authentication callbacks

    def auth_cb(self, *nil):
        """Called in successful logins.
        """
        self.logger.info('Auth callback running')
        self.loading.unref_loading()
        self.list_nodes()

    def auth_failed_cb(self, *nil):
        """Called in unsuccessful logins.
        """
        self.logger.info('Auth failed callback running')
        self.loading.unref_loading()

    # Toolbar callbacks

    def refresh_cb(self, *nil):
        # Clearing node treeview before requesting the listing again.
        self.treeview.get_model().clear()
        self.list_nodes()

    # pubsub stuff

    def parse_list_posts(self, stanza, user_data):
        # traversing to iq > pubsub > items > <first-item>
        node = stanza.child().child().child()
        model = self.treeviewp.get_model()
        model.clear()

        # If there is any item published in the selected node, we list
        # it in the treeviewPosts widget.
        while node:
            # Iterate over the nodes found and append them to the
            # treeviewPosts model.

            # Load the content to an atom entry.
            #model.append([node.find_attrib()])
            node = node.next()
        self.loading.unref_loading()

    def list_posts(self, treeview, path, column):
        model = treeview.get_model()
        giter = model.get_iter(path)
        node = model.get_value(giter, 0)

        # TODO: Inform the user about which node is selected

        # Sending the listing request
        iq = taningia.pubsub.node_items(self.jid_from, self.jid_to, node, 0)
        self.xmpp.send_and_filter(iq, self.parse_list_posts)
        self.loading.ref_loading()

    def parse_list_nodes(self, stanza, user_data):
        model = self.treeview.get_model()
        node = stanza.find('query').child()
        parent_name, parent_iter = user_data
        while node:
            node_name = node.find_attrib('node')
            if not node_name:
                break
            node_iter = model.append(parent_iter, [node_name])
            self.list_nodes(node_name, node_iter)
            node = node.next()
        self.loading.unref_loading()

    def list_nodes(self, node_name=None, node_iter=None):
        args = (self.jid_from, self.jid_to)
        parent_info = node_name or 'root'
        self.logger.info('Listing nodes from %s' % parent_info)
        if node_name is not None:
            args += (node_name,)
        iq = taningia.pubsub.node_query_nodes(*args)
        self.xmpp.send_and_filter(iq, self.parse_list_nodes,
                                  (node_name, node_iter))
        self.loading.ref_loading()

class LoginForm(gtk.Builder):
    """Loads the login.ui file and show it to collect data to connect
    to a Pubsub service.
    """

    def __init__(self):
        super(LoginForm, self).__init__()
        self.add_from_file('login.ui')

    def get_val(self, entry):
        return self.get_object(entry).get_text()

    def run(self):
        return self.get_object('loginDialog').run()

    def destroy(self):
        return self.get_object('loginDialog').destroy()

def main():
    import sys

    if '-d' in sys.argv:
        ctx = {'jid': 'admin@localhost', 'password': 'admin',
               'pservice': 'pubsub.localhost', 'host': '127.0.0.1',
               'port': 5222}
        mwin = MainWindow(ctx)
        mwin.run()
        return

    login = LoginForm()
    if login.run() > 0:
        return

    ctx = {}
    ctx['jid'] = login.get_val('jidEntry')
    ctx['password'] = login.get_val('passwordEntry')
    ctx['host'] = login.get_val('hostEntry')
    ctx['pservice'] = login.get_val('pserviceEntry') \
        or 'pubsub.%s' % ctx['host']
    ctx['port'] = int(login.get_val('portEntry')) \
        or 5222

    login.destroy()

    mwin = MainWindow(ctx)
    mwin.run()

if __name__ == '__main__':
    main()
