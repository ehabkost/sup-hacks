#!/bin/sh

set -x
ruby ./extconf.rb && make && cp ncurses.so lib/ncurses.rb ../lib
