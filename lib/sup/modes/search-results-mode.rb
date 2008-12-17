module Redwood

class SearchResultsMode < ThreadIndexMode
  def initialize qobj, qopts = nil
    @qobj = qobj
    @qopts = qopts

    super [], { :qobj => @qobj }.merge(@qopts)
  end

  register_keymap do |k|
    k.add :refine_search, "Refine search", '|'
  end

  def refine_search
    query = BufferManager.ask :search, "refine query: ", (@qobj.to_s + " ")
    return unless query && query !~ /^\s*$/
    SearchResultsMode.spawn_from_query query
  end

  def self.spawn_from_query text
    begin
      qobj, extraopts = Index.parse_user_query_string(text)
      return unless qobj
      short_text = text.length < 20 ? text : text[0 ... 20] + "..."
      mode = SearchResultsMode.new qobj, extraopts
      BufferManager.spawn "search: \"#{short_text}\"", mode
      mode.load_threads :num => mode.buffer.content_height
    rescue Ferret::QueryParser::QueryParseException => e
      BufferManager.flash "Couldn't parse query."
    end
  end
end

end
