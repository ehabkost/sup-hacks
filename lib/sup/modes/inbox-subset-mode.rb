module Redwood

class InboxSubsetMode < InboxMode
  def self.spawn_nicely label
    label = LabelManager.label_for(label) unless label.is_a?(Symbol)
    case label
    when nil
    when :inbox
      BufferManager.raise_to_front MainInboxMode.instance.buffer
    else
      b, new = BufferManager.spawn_unless_exists("Inbox threads with label '#{label}'") { InboxSubsetMode.new [label] }
      b.mode.load_threads :num => b.content_height if new
    end
  end
end

end
