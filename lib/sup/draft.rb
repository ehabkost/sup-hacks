module Redwood

class DraftManager
  include Singleton

  attr_accessor :source
  def initialize dir
    @dir = dir
    @source = nil
    self.class.i_am_the_instance self
  end

  def self.source_name; "sup://drafts"; end
  def self.source_id; 9999; end
  def new_source; @source = Recoverable.new DraftLoader.new; end

  def write_draft
    offset = @source.gen_offset
    fn = @source.fn_for_offset offset
    File.open(fn, "w") { |f| yield f }

    my_message = nil
    @source.each do |thisoffset, theselabels|
      m = Message.new :source => @source, :source_info => thisoffset, :labels => theselabels
      Index.sync_message m
      UpdateManager.relay self, :added, m
      my_message = m if thisoffset == offset
    end

    my_message
  end

  def discard m
    docid, entry = Index.load_entry_for_id m.id
    unless entry
      Redwood::log "can't find entry for draft: #{m.id.inspect}. You probably already discarded it."
      return
    end
    raise ArgumentError, "not a draft: source id #{entry[:source_id].inspect}, should be #{DraftManager.source_id.inspect} for #{m.id.inspect} / docno #{docid}" unless entry[:source_id].to_i == DraftManager.source_id
    Index.drop_entry docid
    File.delete @source.fn_for_offset(entry[:source_info])
    UpdateManager.relay self, :single_message_deleted, m
  end
end

class DraftLoader < Source
  attr_accessor :dir
  yaml_properties :cur_offset

  def initialize cur_offset=0
    dir = Redwood::DRAFT_DIR
    Dir.mkdir dir unless File.exists? dir
    super DraftManager.source_name, cur_offset, true, false
    @dir = dir
  end

  def id; DraftManager.source_id; end
  def to_s; DraftManager.source_name; end
  def uri; DraftManager.source_name; end

  def each
    ids = get_ids
    ids.each do |id|
      if id >= cur_offset
        self.cur_offset = id + 1
        yield [id, [:draft, :inbox]]
      end
    end
  end

  def gen_offset
    i = cur_offset
    while File.exists? fn_for_offset(i)
      i += 1
    end
    i
  end

  def fn_for_offset o; File.join(@dir, o.to_s); end

  def load_header offset
    File.open fn_for_offset(offset) do |f|
      return MBox::read_header(f)
    end
  end
  
  def load_message offset
    File.open fn_for_offset(offset) do |f|
      RMail::Mailbox::MBoxReader.new(f).each_message do |input|
        return RMail::Parser.read(input)
      end
    end
  end

  def raw_header offset
    ret = ""
    File.open fn_for_offset(offset) do |f|
      until f.eof? || (l = f.gets) =~ /^$/
        ret += l
      end
    end
    ret
  end

  def each_raw_message_line offset
    File.open(fn_for_offset(offset)) do |f|
      yield f.gets until f.eof?
    end
  end

  def raw_message offset
    IO.read(fn_for_offset(offset))
  end

  def start_offset; 0; end
  def end_offset
    ids = get_ids
    ids.empty? ? 0 : (ids.last + 1)
  end

private

  def get_ids
    Dir.entries(@dir).select { |x| x =~ /^\d+$/ }.map { |x| x.to_i }.sort
  end
end

end
