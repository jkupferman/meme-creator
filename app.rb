#!/usr/bin/env ruby
require "rubygems"
require "sinatra"
require "tempfile"
require "yaml"
require "RMagick"
require "dalli"
require "rack-cache"

AVAILABLE_MEMES = YAML.load_file("memes.yml")

ALIASED_MEMES = AVAILABLE_MEMES.inject({}) { |h, e| h[e[1][:alias].to_s] = e[0]; h }

ERROR_MESSAGES = {
  "invalid" => "Y U NO PICK A VALID MEME?! But seriously, the meme name you provided is not valid.",
  "tokens" => "Yo dawg, you are missing some url parameters, try harder."
}

MC = ENV["MEMCACHE_SERVERS"] || "localhost:11211"

use Rack::Cache, {
  :verbose => true,
  :metastore => "memcached://#{MC}",
  :entitystore => "memcached://#{MC}"
}

get "/" do
  expires 300, :public

  @error = params[:error]
  erb :index
end

get "/*" do
  content_type "image/jpeg"
  expires 31104000, :public # cache for a year

  # expects a meme in the format /TOP_STRING/BOTTOM_STRING/MEME_NAME.jpg
  path = URI.decode(request.fullpath.encode("UTF-8", :invalid => :replace, :undef => :replace))
  # replace spaces with underscores to make urls more readable
  redirect path.gsub(" ", "_") if path.include?(" ")

  tokens = path.split("/")

  tokens.shift if tokens.length > 3
  redirect "/?error=tokens" unless tokens.length == 3

  meme_name = tokens[-1].split(".")[0].downcase
  # memeify the text
  top = tokens[0].upcase.gsub("_", " ")
  bottom = tokens[1].upcase.gsub("_", " ")

  meme_name = ALIASED_MEMES[meme_name] if ALIASED_MEMES.include?(meme_name)
  redirect "/?error=invalid" unless AVAILABLE_MEMES.include?(meme_name)

  # default to a space so that memeify works correctly
  top = " " if top.nil? || top.length == 0

  meme = memeify meme_name, top, bottom, AVAILABLE_MEMES[meme_name][:width]
  meme.read
end

def memeify meme, top, bottom, width
  tempfile = Tempfile.new("memeifier", "/tmp/")
  memepath = File.dirname(__FILE__) + "/public/images/meme/#{meme}.jpg"

  # use imagemagick commands to generate the images
  # commands were largely stolen from https://github.com/vquaiato/memish
  convert top, memepath, tempfile.path, "north", width
  convert bottom, tempfile.path, tempfile.path, "south", width

  tempfile
end

def convert text, source, destination, location, width
  fontpath = File.dirname(__FILE__) + "/lib/impact.ttf"
  text = Shellwords.escape(text)
  cmd = "convert -fill white -stroke black -strokewidth 2 -background transparent -gravity center -size #{width}x120 -font #{fontpath} -weight Bold caption:\"#{text}\" #{source} +swap -gravity #{location} -composite #{destination}"
  result = `#{cmd}`
end
