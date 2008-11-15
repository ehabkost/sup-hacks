module Redwood

class MainInboxMode < InboxMode

  def initialize
    super
    raise "can't have more than one!" if defined? @@instance
    @@instance = self
  end

  ## label-list-mode wants to be able to raise us if the user selects
  ## the "inbox" label, so we need to keep our singletonness around
  def self.instance; @@instance; end
  def killable?; false; end
end

end
