#!/usr/bin/ruby

require 'sup'
require 'stringio'
require 'rmail'
require 'uri'

module Redwood

class DummySource < Source

  attr_accessor :messages

  def initialize uri, last_date=nil, usual=true, archived=false, id=nil, labels=[]
    super uri, last_date, usual, archived, id
    @messages = nil
  end

  def start_offset
    0
  end

  def end_offset
    # should contain the number of test messages -1
    return @messages ? @messages.length - 1 : 0
  end

  def load_header offset
    MBox::read_header StringIO.new(raw_header(offset))
  end
  
  def load_message offset
    RMail::Parser.read raw_message(offset)
  end
  
  def raw_header offset
    ret = ""
    f = StringIO.new(@messages[offset])
    until f.eof? || (l = f.gets) =~ /^$/
      ret += l
    end
    ret
  end
  
  def raw_message offset
    @messages[offset]
  end
  
  def each_raw_message_line offset
    ret = ""
    f = StringIO.new(@messages[offset])
    until f.eof?
      yield f.gets
    end
  end

  # FIXME: this one was not mentioned in the source documentation, but
  # it's still required
  def has_errors?

  end

end

end

# vim:noai:ts=2:sw=2:

