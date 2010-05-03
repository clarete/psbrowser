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

class LoginForm(gtk.Builder):
    def __init__(self):
        super(LoginForm, self).__init__()
        self.add_from_file('login.ui')

    def get_val(self, entry):
        return self.get_object(entry).get_text()

    def run(self):
        return self.get_object('loginDialog').run()

class Ui(gtk.Window):
    def __init__(self, inst):
        super(Ui, self).__init__()
        self.pb = inst
        self.connect('delete-event', self.pb.quit)

        self.treeview = gtk.TreeView()
        self.setup()

    def setup(self):
        vbox = gtk.VBox()
        self.add(vbox)

        vbox.pack_start(self.treeview)

class PsBrowser(object):
    def __init__(self, jid, passwd, host, port):
        self.jid = jid
        self.passwd = passwd
        self.host = host
        self.port = port

def main():
    login = LoginForm()
    if login.run() == 0:
        jid = login.get_val('jidEntry')
        password = login.get_val('passwordEntry')
        host = login.get_val('hostEntry')
        port = int(login.get_val('portEntry')) or 5222
        psb = PsBrowser(jid, password, host, port)

if __name__ == '__main__':
    main()
