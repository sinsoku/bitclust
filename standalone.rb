#!/usr/bin/ruby -Ke
#
# $Id: standalone.rb 994 2004-12-08 15:16:41Z aamine $
#
# Stand-alone BitClust server based on WEBrick
#

require 'optparse'

params = {
  :Port => 10080
}
baseurl = nil
dbpath = nil
cgidir = nil
srcdir = nil
templatedir = nil
debugp = false

parser = OptionParser.new
parser.banner = "#{$0} [--port=NUM] --baseurl=URL --database=PATH --cgidir=PATH --srcdir=PATH [--templatedir=PATH] [--debug]"
parser.on('--port=NUM', 'Listening port number') {|num|
  params[:Port] = num.to_i
}
parser.on('--baseurl=URL', 'The base URL to host.') {|url|
  baseurl = url
}
parser.on('--database=PATH', 'Database root directory.') {|path|
  dbpath = path
}
parser.on('--cgidir=PATH', 'Server working directory.') {|path|
  cgidir = path
}
parser.on('--srcdir=PATH', 'BitClust source directory.') {|path|
  srcdir = path
  templatedir ||= "#{srcdir}/template"
  $LOAD_PATH.unshift "#{srcdir}/lib"
}
parser.on('--templatedir=PATH', 'BitClust template directory.') {|path|
  templatedir = path
}
parser.on('--[no-]debug', 'Debug mode.') {|flag|
  debugp = flag
}
parser.on('--help', 'Prints this message and quit.') {
  puts parser.help
  exit 0
}
begin
  parser.parse!
rescue OptionParser::ParseError => err
  $stderr.puts err.message
  $stderr.puts parser.help
  exit 1
end
unless baseurl
  $stderr.puts "missing --baseurl"
  exit 1
end
unless cgidir
  $stderr.puts "missing --cgidir"
  exit 1
end
unless dbpath
  $stderr.puts "missing --database"
  exit 1
end
unless templatedir
  $stderr.puts "missing templatedir; use --srcdir or --templatedir"
  exit 1
end

require 'bitclust'
require 'bitclust/interface'
require 'webrick'

db = BitClust::Database.new(dbpath)
manager = BitClust::ScreenManager.new(
  :base_url => baseurl,
  :cgi_url => "#{baseurl}/view",
  :templatedir => templatedir
)
handler = BitClust::RequestHandler.new(db, manager)

if debugp
  params[:Logger] = WEBrick::Log.new($stderr, WEBrick::Log::DEBUG)
  params[:AccessLog] = [
    [ $stderr, WEBrick::AccessLog::COMMON_LOG_FORMAT  ],
    [ $stderr, WEBrick::AccessLog::REFERER_LOG_FORMAT ],
    [ $stderr, WEBrick::AccessLog::AGENT_LOG_FORMAT   ],
  ]
else
  params[:Logger] = WEBrick::Log.new($stderr, WEBrick::Log::INFO)
  params[:AccessLog] = []
end
server = WEBrick::HTTPServer.new(params)
server.mount '/', BitClust::Interface.new { handler }
server.mount '/theme/', WEBrick::HTTPServlet::FileHandler, "#{cgidir}/theme"
if debugp
  trap(:INT) { server.shutdown }
else
  WEBrick::Daemon.start
end
server.start