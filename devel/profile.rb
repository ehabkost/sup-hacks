require 'rubygems'
require 'ruby-prof'
require "redwood"

result = RubyProf.profile do
  Redwood::ThreadSet.new(ARGV.map { |fn| Redwood::MBox::Scanner.new fn }).load_n_threads nil, 100 # FIXME: query arg?
end

printer = RubyProf::GraphHtmlPrinter.new(result)
File.open("profile.html", "w") { |f| printer.print(f, 1) }
puts "report in profile.html"

