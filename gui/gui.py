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

import gtk
import gobject
import taningia
from threading import Thread

gobject.threads_init()

class MainWindow(gtk.Builder):
    def __init__(self, ctx):
        super(MainWindow, self).__init__()
        self.add_from_file('psbrowser.ui')

        self.is_loading = 0

        # Some important widgets
        self.mwin = self.get_object('mainWindow')
        self.treeview = self.get_object('treeview')
        self.loading = self.get_object('imageLoading')

        # Setting up xmpp stuff
        self.xmpp = taningia.xmpp.Client(
            ctx.get('jid'), ctx.get('password'),
            ctx.get('host'), ctx.get('port'))
        self.xmpp.event_connect('authenticated', self.auth_cb)
        self.xmpp.event_connect('authentication-failed', self.auth_failed_cb)

        # Setting up some ui stuff
        self.loading.set_from_file('data/pixmaps/loading.gif')
        eventbox = self.get_object('titleEventbox')
        eventbox.modify_bg(gtk.STATE_NORMAL,
                           eventbox.get_colormap().alloc_color("#ffffff"))

        # Setting up signals
        self.mwin.connect('delete-event', self.quit)

    def handle_loading(self):
        """Changes the visibility property of our `loading' image
        based on the `self.is_loading' flag. This is important because
        more than one action can request to show/hide it at the same
        time.
        """
        self.loading.set_visible(self.is_loading > 0)

    def ref_loading(self):
        """Increment the loading request and call the loading
        show/hide function.
        """
        self.is_loading += 1
        self.handle_loading()

    def unref_loading(self):
        """Decrement the loading request and call the loading
        show/hide function.
        """
        self.is_loading = max(0, self.is_loading - 1)
        self.handle_loading()

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
        self.ref_loading()
        gtk.main()

    def auth_cb(self, *nil):
        print 'auth'
        self.unref_loading()

    def auth_failed_cb(self, *nil):
        print 'nauth'

class LoginForm(gtk.Builder):

    def __init__(self):
        super(LoginForm, self).__init__()
        self.add_from_file('login.ui')

    def get_val(self, entry):
        return self.get_object(entry).get_text()

    def run(self):
        return self.get_object('loginDialog').run()

def main():
    import sys

    if '-d' in sys.argv:
        ctx = {'jid': 'admin@localhost', 'password': 'admin',
               'host': '127.0.0.1', 'port': 5222}
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
    ctx['port'] = int(login.get_val('portEntry')) or 5222
    mwin = MainWindow(ctx)
    mwin.run()

if __name__ == '__main__':
    main()
