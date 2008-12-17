module Redwood

## subclasses should implement:
## - is_relevant?

class ThreadIndexMode < LineCursorMode
  DATE_WIDTH = Time::TO_NICE_S_MAX_LEN
  MIN_FROM_WIDTH = 15
  LOAD_MORE_THREAD_NUM = 20

  HookManager.register "index-mode-size-widget", <<EOS
Generates the per-thread size widget for each thread.
Variables:
  thread: The message thread to be formatted.
EOS

  HookManager.register "mark-as-spam", <<EOS
This hook is run when a thread is marked as spam
Variables:
  thread: The message thread being marked as spam.
EOS

  register_keymap do |k|
    k.add :load_threads, "Load #{LOAD_MORE_THREAD_NUM} more threads", 'M'
    k.add_multi "Load all threads (! to confirm) :", '!' do |kk|
      kk.add :load_all_threads, "Load all threads (may list a _lot_ of threads)", '!'
    end
    k.add :cancel_search, "Cancel current search", :ctrl_g
    k.add :reload, "Refresh view", '@'
    k.add :toggle_archived, "Toggle archived status", 'a'
    k.add :toggle_starred, "Star or unstar all messages in thread", '*'
    k.add :toggle_new, "Toggle new/read status of all messages in thread", 'N'
    k.add :edit_labels, "Edit or add labels for a thread", 'l'
    k.add :edit_message, "Edit message (drafts only)", 'e'
    k.add :toggle_spam, "Mark/unmark thread as spam", 'S'
    k.add :toggle_deleted, "Delete/undelete thread", 'd'
    k.add :kill, "Kill thread (never to be seen in inbox again)", '&'
    k.add :save, "Save changes now", '$'
    k.add :jump_to_next_new, "Jump to next new thread", :tab
    k.add :reply, "Reply to latest message in a thread", 'r'
    k.add :forward, "Forward latest message in a thread", 'f'
    k.add :toggle_tagged, "Tag/untag selected thread", 't'
    k.add :toggle_tagged_all, "Tag/untag all threads", 'T'
    k.add :tag_matching, "Tag matching threads", 'g'
    k.add :apply_to_tagged, "Apply next command to all tagged threads", ';'
    k.add :join_threads, "Force tagged threads to be joined into the same thread", '#'
  end

  def initialize hidden_labels=[], load_thread_opts={}
    super()
    @mutex = Mutex.new # covers the following variables:
    @threads = {}
    @hidden_threads = {}
    @size_widget_width = nil
    @size_widgets = {}
    @tags = Tagger.new self

    ## these guys, and @text and @lines, are not covered
    @load_thread = nil
    @load_thread_opts = load_thread_opts
    @query = Index.instance.build_query load_thread_opts
    @hidden_labels = hidden_labels + LabelManager::HIDDEN_RESERVED_LABELS
    @date_width = DATE_WIDTH

    @interrupt_search = false
    
    initialize_threads # defines @ts and @ts_mutex
    update # defines @text and @lines

    UpdateManager.register self

    @last_load_more_size = nil
    to_load_more do |size|
      next if @last_load_more_size == 0
      load_threads :num => 1, :background => false
      load_threads :num => (size - 1),
                   :when_done => lambda { |num| @last_load_more_size = num }
    end
  end

  def lines; @text.length; end
  def [] i; @text[i]; end
  def contains_thread? t; @threads.include?(t) end

  def reload
    drop_all_threads
    BufferManager.draw_screen
    load_threads :num => buffer.content_height
  end

  ## open up a thread view window
  def select t=nil, when_done=nil
    t ||= cursor_thread or return

    Redwood::reporting_thread("load messages for thread-view-mode") do
      num = t.size
      message = "Loading #{num.pluralize 'message body'}..."
      BufferManager.say(message) do |sid|
        t.each_with_index do |(m, *o), i|
          next unless m
          BufferManager.say "#{message} (#{i}/#{num})", sid if t.size > 1
          m.load_from_source! 
        end
      end
      mode = ThreadViewMode.new t, @hidden_labels, self
      BufferManager.spawn t.subj, mode
      BufferManager.draw_screen
      mode.jump_to_first_open true
      BufferManager.draw_screen # lame TODO: make this unnecessary
      ## the first draw_screen is needed before topline and botline
      ## are set, and the second to show the cursor having moved

      update_text_for_line curpos
      UpdateManager.relay self, :read, t.first
      when_done.call if when_done
    end
  end

  def multi_select threads
    threads.each { |t| select t }
  end

  ## these two methods are called by thread-view-modes when the user
  ## wants to view the previous/next thread without going back to
  ## index-mode. we update the cursor as a convenience.
  def launch_next_thread_after thread, &b
    launch_another_thread thread, 1, &b
  end

  def launch_prev_thread_before thread, &b
    launch_another_thread thread, -1, &b
  end

  def launch_another_thread thread, direction, &b
    l = @lines[thread] or return
    target_l = l + direction
    t = @mutex.synchronize do
      if target_l >= 0 && target_l < @threads.length
        @threads[target_l]
      end
    end

    if t # there's a next thread
      set_cursor_pos target_l # move out of mutex?
      select t, b
    elsif b # no next thread. call the block anyways
      b.call
    end
  end
  
  def handle_single_message_labeled_update sender, m
    ## no need to do anything different here; we don't differentiate 
    ## messages from their containing threads
    handle_labeled_update sender, m
  end

  def handle_labeled_update sender, m
    if(t = thread_containing(m)) 
      l = @lines[t] or return
      update_text_for_line l
    elsif is_relevant?(m)
      add_or_unhide m
    end
  end

  def handle_simple_update sender, m
    t = thread_containing(m) or return
    l = @lines[t] or return
    update_text_for_line l
  end

  %w(read unread archived starred unstarred).each do |state|
    define_method "handle_#{state}_update" do |*a|
      handle_simple_update(*a)
    end
  end

  def is_relevant? m
    return Index.instance.matches_query? m.id, @query
  end


  def handle_added_update sender, m
    add_or_unhide m
    BufferManager.draw_screen
  end

  def handle_single_message_deleted_update sender, m
    @ts_mutex.synchronize do
      return unless @ts.contains? m
      @ts.remove_id m.id
    end
    update
  end

  def handle_deleted_update sender, m
    t = @ts_mutex.synchronize { @ts.thread_for m }
    return unless t
    hide_thread t
    update
  end

  def handle_spammed_update sender, m
    t = @ts_mutex.synchronize { @ts.thread_for m }
    return unless t
    hide_thread t
    update
  end

  def handle_undeleted_update sender, m
    add_or_unhide m
  end

  def update
    @mutex.synchronize do
      ## let's see you do THIS in python
      @threads = @ts.threads.select { |t| !@hidden_threads[t] }.sort_by { |t| [t.date, t.first.id] }.reverse
      @size_widgets = @threads.map { |t| size_widget_for_thread t }
      @size_widget_width = @size_widgets.max_of { |w| w.length }
    end

    regen_text
  end

  def edit_message
    return unless(t = cursor_thread)
    message, *crap = t.find { |m, *o| m.has_label? :draft }
    if message
      mode = ResumeMode.new message
      BufferManager.spawn "Edit message", mode
    else
      BufferManager.flash "Not a draft message!"
    end
  end

  def actually_toggle_starred t
    if t.has_label? :starred # if ANY message has a star
      t.remove_label :starred # remove from all
      UpdateManager.relay self, :unstarred, t.first
    else
      t.first.add_label :starred # add only to first
      UpdateManager.relay self, :starred, t.first
    end
  end  

  def toggle_starred 
    t = cursor_thread or return
    actually_toggle_starred t
    update_text_for_line curpos
    cursor_down
  end

  def multi_toggle_starred threads
    threads.each { |t| actually_toggle_starred t }
    regen_text
  end

  def actually_toggle_archived t
    if t.has_label? :inbox
      t.remove_label :inbox
      UpdateManager.relay self, :archived, t.first
    else
      t.apply_label :inbox
      UpdateManager.relay self, :unarchived, t.first
    end
  end

  def actually_toggle_spammed t
    if t.has_label? :spam
      t.remove_label :spam
      UpdateManager.relay self, :unspammed, t.first
    else
      t.apply_label :spam
      UpdateManager.relay self, :spammed, t.first
    end
  end

  def actually_toggle_deleted t
    if t.has_label? :deleted
      t.remove_label :deleted
      UpdateManager.relay self, :undeleted, t.first
    else
      t.apply_label :deleted
      UpdateManager.relay self, :deleted, t.first
    end
  end

  def toggle_archived 
    t = cursor_thread or return
    actually_toggle_archived t
    update_text_for_line curpos
  end

  def multi_toggle_archived threads
    threads.each { |t| actually_toggle_archived t }
    regen_text
  end

  def toggle_new
    t = cursor_thread or return
    t.toggle_label :unread
    update_text_for_line curpos
    cursor_down
  end

  def multi_toggle_new threads
    threads.each { |t| t.toggle_label :unread }
    regen_text
  end

  def multi_toggle_tagged threads
    @mutex.synchronize { @tags.drop_all_tags }
    regen_text
  end

  def join_threads
    ## this command has no non-tagged form. as a convenience, allow this
    ## command to be applied to tagged threads without hitting ';'.
    @tags.apply_to_tagged :join_threads
  end

  def multi_join_threads threads
    @ts.join_threads threads or return
    @tags.drop_all_tags # otherwise we have tag pointers to invalid threads!
    update
  end

  def jump_to_next_new
    n = @mutex.synchronize do
      ((curpos + 1) ... lines).find { |i| @threads[i].has_label? :unread } ||
        (0 ... curpos).find { |i| @threads[i].has_label? :unread }
    end
    if n
      ## jump there if necessary
      jump_to_line n unless n >= topline && n < botline
      set_cursor_pos n
    else
      BufferManager.flash "No new messages"
    end
  end

  def toggle_spam
    t = cursor_thread or return
    multi_toggle_spam [t]
    HookManager.run("mark-as-spam", :thread => t)
  end

  ## both spam and deleted have the curious characteristic that you
  ## always want to hide the thread after either applying or removing
  ## that label. in all thread-index-views except for
  ## label-search-results-mode, when you mark a message as spam or
  ## deleted, you want it to disappear immediately; in LSRM, you only
  ## see deleted or spam emails, and when you undelete or unspam them
  ## you also want them to disappear immediately.
  def multi_toggle_spam threads
    threads.each do |t|
      actually_toggle_spammed t
      hide_thread t 
    end
    regen_text
  end

  def toggle_deleted
    t = cursor_thread or return
    multi_toggle_deleted [t]
  end

  ## see comment for multi_toggle_spam
  def multi_toggle_deleted threads
    threads.each do |t|
      actually_toggle_deleted t
      hide_thread t 
    end
    regen_text
  end

  def kill
    t = cursor_thread or return
    multi_kill [t]
  end

  def multi_kill threads
    threads.each do |t|
      t.apply_label :killed
      hide_thread t
    end
    regen_text
    BufferManager.flash "#{threads.size.pluralize 'Thread'} killed."
  end

  def save
    BufferManager.say("Saving contacts...") { ContactManager.instance.save }
    dirty_threads = @mutex.synchronize { (@threads + @hidden_threads.keys).select { |t| t.dirty? } }
    return if dirty_threads.empty?

    BufferManager.say("Saving threads...") do |say_id|
      dirty_threads.each_with_index do |t, i|
        BufferManager.say "Saving modified thread #{i + 1} of #{dirty_threads.length}...", say_id
        t.save Index
      end
    end
  end

  def cleanup
    UpdateManager.unregister self

    if @load_thread
      @load_thread.kill 
      BufferManager.clear @mbid if @mbid
      sleep 0.1 # TODO: necessary?
      BufferManager.erase_flash
    end
    save
    super
  end

  def toggle_tagged
    t = cursor_thread or return
    @mutex.synchronize { @tags.toggle_tag_for t }
    update_text_for_line curpos
    cursor_down
  end
  
  def toggle_tagged_all
    @mutex.synchronize { @threads.each { |t| @tags.toggle_tag_for t } }
    regen_text
  end

  def tag_matching
    query = BufferManager.ask :search, "tag threads matching: "
    return if query.nil? || query.empty?
    query = /#{query}/i
    @mutex.synchronize { @threads.each { |t| @tags.tag t if thread_matches?(t, query) } }
    regen_text
  end

  def apply_to_tagged; @tags.apply_to_tagged; end

  def edit_labels
    thread = cursor_thread or return
    speciall = (@hidden_labels + LabelManager::RESERVED_LABELS).uniq
    keepl, modifyl = thread.labels.partition { |t| speciall.member? t }

    user_labels = BufferManager.ask_for_labels :label, "Labels for thread: ", modifyl, @hidden_labels

    return unless user_labels
    thread.labels = keepl + user_labels
    user_labels.each { |l| LabelManager << l }
    update_text_for_line curpos
    UpdateManager.relay self, :labeled, thread.first
  end

  def multi_edit_labels threads
    user_labels = BufferManager.ask_for_labels :add_labels, "Add labels: ", [], @hidden_labels
    return unless user_labels
    
    hl = user_labels.select { |l| @hidden_labels.member? l }
    if hl.empty?
      threads.each { |t| user_labels.each { |l| t.apply_label l } }
      user_labels.each { |l| LabelManager << l }
    else
      BufferManager.flash "'#{hl}' is a reserved label!"
    end
    regen_text
  end

  def reply
    t = cursor_thread or return
    m = t.latest_message
    return if m.nil? # probably won't happen
    m.load_from_source!
    mode = ReplyMode.new m
    BufferManager.spawn "Reply to #{m.subj}", mode
  end

  def forward
    t = cursor_thread or return
    m = t.latest_message
    return if m.nil? # probably won't happen
    m.load_from_source!
    ForwardMode.spawn_nicely :message => m
  end

  def load_n_threads_background query, n=LOAD_MORE_THREAD_NUM, query_opts={}
    return if @load_thread # todo: wrap in mutex
    @load_thread = Redwood::reporting_thread("load threads for thread-index-mode") do
      num = load_n_threads query, n, query_opts
      yield num if block_given?
      @load_thread = nil
    end
  end

  ## TODO: figure out @ts_mutex in this method
  def load_n_threads query, n=LOAD_MORE_THREAD_NUM, query_opts={}
    @interrupt_search = false
    @mbid = BufferManager.say "Searching for threads..."

    ts_to_load = n
    ts_to_load = ts_to_load + @ts.size unless n == -1 # -1 means all threads

    orig_size = @ts.size
    last_update = Time.now
    @ts.load_n_threads(query, ts_to_load, query_opts) do |i|
      if (Time.now - last_update) >= 0.25
        BufferManager.say "Loaded #{i.pluralize 'thread'}...", @mbid
        update
        BufferManager.draw_screen
        last_update = Time.now
      end
      break if @interrupt_search
    end
    @ts.threads.each { |th| th.labels.each { |l| LabelManager << l } }

    update
    BufferManager.clear @mbid
    @mbid = nil
    BufferManager.draw_screen
    @ts.size - orig_size
  end
  ignore_concurrent_calls :load_n_threads

  def status
    if (l = lines) == 0
      "line 0 of 0"
    else
      "line #{curpos + 1} of #{l} #{dirty? ? '*modified*' : ''}"
    end
  end

  def cancel_search
    @interrupt_search = true
  end

  def load_all_threads
    load_threads :num => -1
  end

  def load_threads opts={}
    if opts[:num].nil?
      n = ThreadIndexMode::LOAD_MORE_THREAD_NUM
    else
      n = opts[:num]
    end

    query_opts = @load_thread_opts

    if opts[:background] || opts[:background].nil?
      load_n_threads_background(@query, n, query_opts) { |num|
        opts[:when_done].call(num) if opts[:when_done]

        if num > 0
          BufferManager.flash "Found #{num.pluralize 'thread'}."
        else
          BufferManager.flash "No matches."
        end
      }
    else
      load_n_threads(@query, n, query_opts)
    end
  end
  ignore_concurrent_calls :load_threads

  def resize rows, cols
    regen_text
    super
  end

protected

  def add_or_unhide m
    @ts_mutex.synchronize do
      if (is_relevant?(m) || @ts.is_relevant?(m)) && !@ts.contains?(m)
        @ts.load_thread_for_message m
      end

      @hidden_threads.delete @ts.thread_for(m)
    end

    update
  end

  def thread_containing m; @ts_mutex.synchronize { @ts.thread_for m } end

  ## used to tag threads by query. this can be made a lot more sophisticated,
  ## but for right now we'll do the obvious this.
  def thread_matches? t, query
    t.subj =~ query || t.snippet =~ query || t.participants.any? { |x| x.longname =~ query }
  end

  def size_widget_for_thread t
    HookManager.run("index-mode-size-widget", :thread => t) || default_size_widget_for(t)
  end

  def cursor_thread; @mutex.synchronize { @threads[curpos] }; end

  def drop_all_threads
    @tags.drop_all_tags
    initialize_threads
    update
  end

  def hide_thread t
    @mutex.synchronize do
      i = @threads.index(t) or return
      raise "already hidden" if @hidden_threads[t]
      @hidden_threads[t] = true
      @threads.delete_at i
      @size_widgets.delete_at i
      @tags.drop_tag_for t
    end
  end

  def update_text_for_line l
    return unless l # not sure why this happens, but it does, occasionally
    
    need_update = false

    @mutex.synchronize do
      @size_widgets[l] = size_widget_for_thread @threads[l]

      ## if the widget size has increased, we need to redraw everyone
      need_update = @size_widgets[l].size > @size_widget_width
    end

    if need_update
      update
    else
      @text[l] = text_for_thread_at l
      buffer.mark_dirty if buffer
    end
  end

  def regen_text
    threads = @mutex.synchronize { @threads }
    @text = threads.map_with_index { |t, i| text_for_thread_at i }
    @lines = threads.map_with_index { |t, i| [t, i] }.to_h
    buffer.mark_dirty if buffer
  end
  
  def authors; map { |m, *o| m.from if m }.compact.uniq; end

  def author_names_and_newness_for_thread t
    new = {}
    authors = t.map do |m, *o|
      next unless m

      name = 
        if AccountManager.is_account?(m.from)
          "me"
        elsif t.authors.size == 1
          m.from.mediumname
        else
          m.from.shortname
        end

      new[name] ||= m.has_label?(:unread)
      name
    end

    authors.compact.uniq.map { |a| [a, new[a]] }
  end

  def text_for_thread_at line
    t, size_widget = @mutex.synchronize { [@threads[line], @size_widgets[line]] }

    date = t.date.to_nice_s

    starred = t.has_label?(:starred)

    ## format the from column
    cur_width = 0
    ann = author_names_and_newness_for_thread t
    from = []
    ann.each_with_index do |(name, newness), i|
      break if cur_width >= from_width
      last = i == ann.length - 1

      abbrev =
        if cur_width + name.length > from_width
          name[0 ... (from_width - cur_width - 1)] + "."
        elsif cur_width + name.length == from_width
          name[0 ... (from_width - cur_width)]
        else
          if last
            name[0 ... (from_width - cur_width)]
          else
            name[0 ... (from_width - cur_width - 1)] + "," 
          end
        end

      cur_width += abbrev.length

      if last && from_width > cur_width
        abbrev += " " * (from_width - cur_width)
      end

      from << [(newness ? :index_new_color : (starred ? :index_starred_color : :index_old_color)), abbrev]
    end

    dp = t.direct_participants.any? { |p| AccountManager.is_account? p }
    p = dp || t.participants.any? { |p| AccountManager.is_account? p }

    subj_color =
      if t.has_label?(:draft)
        :index_draft_color
      elsif t.has_label?(:unread)
        :index_new_color
      elsif starred
        :index_starred_color
      else 
        :index_old_color
      end

    snippet = t.snippet + (t.snippet.empty? ? "" : "...")

    size_widget_text = sprintf "%#{ @size_widget_width}s", size_widget

    [ 
      [:tagged_color, @tags.tagged?(t) ? ">" : " "],
      [:none, sprintf("%#{@date_width}s", date)],
      (starred ? [:starred_color, "*"] : [:none, " "]),
    ] +
      from +
      [
      [subj_color, size_widget_text],
      [:to_me_color, t.labels.member?(:attachment) ? "@" : " "],
      [:to_me_color, dp ? ">" : (p ? '+' : " ")],
      [subj_color, t.subj + (t.subj.empty? ? "" : " ")],
    ] +
      (t.labels - @hidden_labels).map { |label| [:label_color, "+#{label} "] } +
      [[:snippet_color, snippet]
    ]

  end

  def dirty?; @mutex.synchronize { (@hidden_threads.keys + @threads).any? { |t| t.dirty? } } end

private

  def default_size_widget_for t
    case t.size
    when 1
      ""
    else
      "(#{t.size})"
    end
  end

  def from_width
    [(buffer.content_width.to_f * 0.2).to_i, MIN_FROM_WIDTH].max
  end

  def initialize_threads
    @ts = ThreadSet.new Index.instance, $config[:thread_by_subject]
    @ts_mutex = Mutex.new
    @hidden_threads = {}
  end
end

end
