sup
    by William Morgan <wmorgan-sup@masanjin.net>
    http://sup.rubyforge.org

== DESCRIPTION:

Sup is a console-based email client for people with a lot of email.
It supports tagging, very fast full-text search, automatic contact-
list management, and more. If you're the type of person who treats
email as an extension of your long-term memory, Sup is for you.

Sup makes it easy to:
- Handle massive amounts of email.

- Mix email from different sources: mbox files (even across different
  machines), Maildir directories, IMAP folders, POP accounts, and
  GMail accounts.

- Instantaneously search over your entire email collection. Search
  over body text, or use a query language to combine search
  predicates in any way.

- Handle multiple accounts. Replying to email sent to a particular
  account will use the correct SMTP server, signature, and from
  address.

- Add custom code to handle certain types of messages or to handle
  certain types of text within messages.

- Organize email with user-defined labels, automatically track
  recent contacts, and much more!

The goal of Sup is to become the email client of choice for nerds
everywhere.

== FEATURES/PROBLEMS:

Features:

- Scalability to massive amounts of email. Immediate startup and
  operability, regardless of how much amount of email you have.

- Immediate full-text search of your entire email archive, using the
  Ferret query language. Search over message bodies, labels, from: and
  to: fields, or any combination thereof.

- Thread-centrism. Operations are performed at the thread, not the
  message level. Entire threads are manipulated and viewed (with
  redundancies removed) at a time.

- Labels instead of folders. Drop that tired old metaphor and you'll
  see how much easier it is to organize email.

- GMail-style thread management (but better!). Archive a thread, and
  it will disappear from your inbox until someone replies. Kill a
  thread, and it will never come back to your inbox (but will still
  show up in searches.) Mark a thread as spam and you'll never again
  see it unless explicitly searching for spam.

- Console based interface. No mouse clicking required!

- Programmability. It's in Ruby. The code is good. It's easy to
  extend.

- Multiple buffer support. Why be limited to viewing one thread at a
  time?

- Tons of other little features, like automatic context-sensitive
  help, multi-message operations, MIME attachment viewing, recent
  contact list generation, etc.

Current limitations which will be fixed:

- Support for mbox, remote mbox, and IMAP only at this point. No
  support for POP, mh, or GMail mailstores.

- No internationalization support. No wide characters, no subject
  demangling. 

- Unix-centrism in MIME attachment handling and in sendmail
  invocation.

- Several obvious missing features, like undo, filters / saved
  searches, message annotations, etc.

== SYNOPSYS:

  0. sup-config
  1. sup

  Note that Sup never changes the contents of any mailboxes; it only
  indexes in to them. So it shouldn't ever corrupt your mail. The flip
  side is that if you change a mailbox (e.g. delete messages, or, in
  the case of mbox files, read an unread message) then Sup will be
  unable to load messages from that source and will ask you to run
  sup-sync --changed.

== REQUIREMENTS:

* ferret >= 0.10.13
* ncurses
* rmail
* highline
* net-ssh
* trollop >= 1.7
* lockfile
* mime-types

== INSTALL:

* gem install sup -y

== PROBLEMS:

See FAQ.txt for some common problems and their solutions.

== LICENSE:

Copyright (c) 2006, 2007 William Morgan.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
02110-1301, USA.

