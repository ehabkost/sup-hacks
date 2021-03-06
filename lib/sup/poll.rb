require 'thread'

module Redwood

class PollManager
  include Singleton

  HookManager.register "before-add-message", <<EOS
Executes immediately before a message is added to the index.
Variables:
  message: the new message
EOS

  HookManager.register "before-poll", <<EOS
Executes immediately before a poll for new messages commences.
No variables.
EOS

  HookManager.register "after-poll", <<EOS
Executes immediately after a poll for new messages completes.
Variables:
                   num: the total number of new messages added in this poll
             num_inbox: the number of new messages added in this poll which
                        appear in the inbox (i.e. were not auto-archived).
num_inbox_total_unread: the total number of unread messages in the inbox
         from_and_subj: an array of (from email address, subject) pairs
   from_and_subj_inbox: an array of (from email address, subject) pairs for
                        only those messages appearing in the inbox
EOS

  DELAY = 300

  def initialize
    @mutex = Mutex.new
    @thread = nil
    @last_poll = nil
    @polling = false
    
    self.class.i_am_the_instance self
  end

  def buffer
    b, new = BufferManager.spawn_unless_exists("<poll for new messages>", :hidden => true) { PollMode.new }
    b
  end

  def poll
    return if @polling
    @polling = true
    HookManager.run "before-poll"

    BufferManager.flash "Polling for new messages..."
    num, numi, from_and_subj, from_and_subj_inbox = buffer.mode.poll
    if num > 0
      BufferManager.flash "Loaded #{num.pluralize 'new message'}, #{numi} to inbox." 
    else
      BufferManager.flash "No new messages." 
    end

    HookManager.run "after-poll", :num => num, :num_inbox => numi, :from_and_subj => from_and_subj, :from_and_subj_inbox => from_and_subj_inbox, :num_inbox_total_unread => lambda { Index.num_results_for :labels => [:inbox, :unread] }

    @polling = false
    [num, numi]
  end

  def start
    @thread = Redwood::reporting_thread("periodic poll") do
      while true
        sleep DELAY / 2
        poll if @last_poll.nil? || (Time.now - @last_poll) >= DELAY
      end
    end
  end

  def stop
    @thread.kill if @thread
    @thread = nil
  end

  def do_poll
    total_num = total_numi = 0
    from_and_subj = []
    from_and_subj_inbox = []

    @mutex.synchronize do
      Index.usual_sources.each do |source|
#        yield "source #{source} is done? #{source.done?} (cur_offset #{source.cur_offset} >= #{source.end_offset})"
        begin
          yield "Loading from #{source}... " unless source.done? || source.has_errors?
        rescue SourceError => e
          Redwood::log "problem getting messages from #{source}: #{e.message}"
          Redwood::report_broken_sources :force_to_top => true
          next
        end

        num = 0
        numi = 0
        add_messages_from source do |m, offset, entry|
          ## always preserve the labels on disk.
          m.labels = entry[:label].split(/\s+/).map { |x| x.intern } if entry
          yield "Found message at #{offset} with labels {#{m.labels * ', '}}"
          unless entry
            num += 1
            from_and_subj << [m.from.longname, m.subj]
            if m.has_label?(:inbox) && ([:spam, :deleted, :killed] & m.labels).empty?
              from_and_subj_inbox << [m.from.longname, m.subj]
              numi += 1 
            end
          end
          m
        end
        yield "Found #{num} messages, #{numi} to inbox." unless num == 0
        total_num += num
        total_numi += numi
      end

      yield "Done polling; loaded #{total_num} new messages total"
      @last_poll = Time.now
      @polling = false
    end
    [total_num, total_numi, from_and_subj, from_and_subj_inbox]
  end

  ## this is the main mechanism for adding new messages to the
  ## index. it's called both by sup-sync and by PollMode.
  ##
  ## for each message in the source, starting from the source's
  ## starting offset, this methods yields the message, the source
  ## offset, and the index entry on disk (if any). it expects the
  ## yield to return the message (possibly altered in some way), and
  ## then adds it (if new) or updates it (if previously seen).
  ##
  ## the labels of the yielded message are the default source
  ## labels. it is likely that callers will want to replace these with
  ## the index labels, if they exist, so that state is not lost when
  ## e.g. a new version of a message from a mailing list comes in.
  def add_messages_from source, opts={}
    begin
      return if source.done? || source.has_errors?
      
      source.each do |offset, labels|
        if source.has_errors?
          Redwood::log "error loading messages from #{source}: #{source.error.message}"
          return
        end
      
        labels.each { |l| LabelManager << l }
        labels = labels + (source.archived? ? [] : [:inbox])

        begin
          m = Message.new :source => source, :source_info => offset, :labels => labels
          if m.source_marked_read?
            m.remove_label :unread
            labels.delete :unread
          end

          docid, entry = Index.load_entry_for_id m.id
          HookManager.run "before-add-message", :message => m
          m = yield(m, offset, entry) or next if block_given?
          Index.sync_message m, docid, entry, opts
          UpdateManager.relay self, :added, m unless entry
        rescue MessageFormatError => e
          Redwood::log "ignoring erroneous message at #{source}##{offset}: #{e.message}"
        end
      end
    rescue SourceError => e
      Redwood::log "problem getting messages from #{source}: #{e.message}"
      Redwood::report_broken_sources :force_to_top => true
    end
  end
end

end
