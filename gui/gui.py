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
import sys
import uuid
from datetime import datetime

gobject.threads_init()

def report_error(title, msg, parent=None, exit_code=-1):
    """A function that shows an error message box.
    """
    dialog = gtk.MessageDialog(parent=parent,
                               type=gtk.MESSAGE_ERROR,
                               buttons=gtk.BUTTONS_CLOSE)
    dialog.set_position(gtk.WIN_POS_CENTER_ON_PARENT)
    dialog.set_markup('<b><big>%s</big></b>' % title)
    dialog.format_secondary_markup(msg)
    dialog.show()
    dialog.run()
    dialog.destroy()
    if exit_code != -1:
        sys.exit(exit_code)

def iserror(stanza):
    return stanza.find_attrib('type') == 'error'

def errname(stanza):
    try:
        ename = stanza.find('error').child().name()
    except AttributeError:
        return None
    ename = ename.replace('-', ' ')
    ename = ename.capitalize()
    return ename

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

        # Path to be expanded after loading node tree
        self.path_to_expand = ()

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
        self.get_object('tbRemove').connect('clicked', self.remove_cb)
        self.get_object('tbAdd').connect('clicked', self.newnode_cb)
        self.get_object('tbPublish').connect('clicked', self.publish_cb)

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
        self.mwin.set_title('PsBrowser - %s' % self.jid_from)
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

    def remove_cb(self, *nil):
        """Removes all selected nodes in the treeview.
        """
        self.remove_selected_node()

    def newnode_cb(self, *nil):
        """Calls the newnode form to create a new node.
        """
        nnf = NewNodeForm(self)
        nnf.run()
        nnf.destroy()

    def publish_cb(self, *nil):
        pub = PublishAtomForm(self)
        pub.run()
        #pub.destroy()

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
        if self.path_to_expand:
            self.treeview.expand_to_path(self.path_to_expand)
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

    def parse_remove_node(self, stanza, user_data):
        self.loading.unref_loading()
        if iserror(stanza):
            err = errname(stanza)
            report_error(
                'Could not remove selected node',
                'The server returned the error <b>%s</b>' % err,
                self.mwin)
            self.logger.warn('Could note remove node %s: %s' %
                             (user_data, err))
        else:
            self.refresh_cb()

    def remove_selected_node(self, *nil):
        selection = self.treeview.get_selection()
        model, giter = selection.get_selected()
        if giter:
            # we have stuff selected =D
            node = model.get_value(giter, 0)
            iq = taningia.pubsub.node_delete(self.jid_from, self.jid_to, node)
            self.xmpp.send_and_filter(iq, self.parse_remove_node, node)
            parent = model.iter_parent(giter)
            if parent:
                self.path_to_expand = model.get_path(parent)
            self.logger.info('Requesting to remove node %s' % node)
            self.loading.ref_loading()

    def parse_add_node(self, stanza, user_data):
        self.loading.unref_loading()
        if iserror(stanza):
            err = errname(stanza)
            report_error(
                'Node `%s\' was not created' % user_data,
                'The server returned the error <b>%s</b>' % err,
                self.mwin)
        else:
            self.refresh_cb()

    def add_node(self, node, ntype):
        params = self.jid_from, self.jid_to, node, {'type': ntype}
        iq = taningia.pubsub.node_create(*params)
        self.xmpp.send_and_filter(iq, self.parse_add_node, node)
        self.loading.ref_loading()

class PublishAtomForm(gtk.Builder):
    def __init__(self, main):
        super(PublishAtomForm, self).__init__()
        self.add_from_file('publish_atom2.ui')
        self.main = main
        self.treeview = self.get_object('treeviewTags')
        self.mdialog = self.get_object('mainDialog')
        self.mdialog.set_transient_for(self.main.mwin)

        # some UI stuff
        self.setup_treeviews()
        self.get_object('nodeIdEntry').set_icon_tooltip_text(
            gtk.ENTRY_ICON_SECONDARY,
            'Generate a random uuid for this entry')

        # setting default values
        now = datetime.now().strftime('%Y/%m/%d %X')
        self.get_object('publishedDateEntry').set_text(now)
        self.get_object('updatedDateEntry').set_text(now)


        # setting up signals
        self.mdialog.connect('cancel', self.destroy)
        self.get_object('nodeIdEntry').connect(
            'icon-press', self.gen_id)
        self.get_object('nodeTitleEntry').connect(
            'changed', self.update_ok_state)
        self.get_object('nodeIdEntry').connect(
            'changed', self.update_ok_state)
        self.get_object('publishedDateEntry').connect(
            'changed', self.update_ok_state)
        self.get_object('updatedDateEntry').connect(
            'changed', self.update_ok_state)
        self.get_object('btAdd').connect('clicked', self.add_row)

    def run(self):
        return self.mdialog.show_all()

    def destroy(self, *nil):
        return self.mdialog.destroy()

    def setup_treeviews(self):
        """Sets up renderers and columns for tags treeview.
        """
        self.label_cell = renderer = gtk.CellRendererText()
        column = gtk.TreeViewColumn('Label', renderer, text=0, editable=2)
        self.treeview.append_column(column)

        renderer = gtk.CellRendererText()
        column = gtk.TreeViewColumn('Uri', renderer, text=1, editable=2)
        self.treeview.append_column(column)

    def add_row(self, button):
        model = self.treeview.get_model()
        giter = model.append(['a', 'b', True])
        path = model.get_path(giter)

        # We're sure that both indexes exists, they were added by the
        # `self.setup_treeviews()' method.
        column = self.treeview.get_columns()[0]
        cell = column.get_cell_renderers()[0]
        column.focus_cell(cell)

    def gen_id(self, entry, *nil):
        urn = 'urn:uuid:%s' % uuid.uuid4()
        entry.set_text(urn)

    def update_ok_state(self, *nil):
        page = self.get_object('page1')
        enabled = True
        for i in [
            'nodeTitleEntry', 'nodeIdEntry',
            'publishedDateEntry', 'updatedDateEntry']:
            obj = self.get_object(i)
            if not obj.get_text().strip():
                enabled = False

        # TODO: validate date fields
        self.mdialog.set_page_complete(page, enabled)

class NewNodeForm(gtk.Builder):
    """Loads the newnode.ui file, grab necessary info to create a new
    node.
    """
    def __init__(self, main):
        super(NewNodeForm, self).__init__()
        self.add_from_file('newnode.ui')
        self.main = main
        self.get_object('mainDialog').set_transient_for(self.main.mwin)

        # Connecting signals

        self.get_object('nodeNameEntry').connect(
            'changed', self.set_ok_sensitivity_cb)
        self.get_object('btOk').connect(
            'clicked', self.create_node_cb)

    def run(self):
        if self.get_object('mainDialog').run() == 1:
            is_leaf = self.get_object('rbTypeLeaf').get_active()
            node_type = is_leaf and 'leaf' or 'collection'
            self.main.add_node(
                self.get_object('nodeNameEntry').get_text(),
                node_type)

    def destroy(self):
        return self.get_object('mainDialog').destroy()

    # callbacks

    def set_ok_sensitivity_cb(self, entry):
        self.get_object('btOk').set_sensitive(bool(entry.get_text().strip()))

    def create_node_cb(self, button):
        node = self.get_object('nodeNameEntry').get_text()

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
