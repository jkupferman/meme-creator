#!/usr/bin/env ruby
require "rubygems"
require "sinatra"
require "tempfile"
require "yaml"
require "open-uri"
require "RMagick"
require "dalli"
require "rack-cache"
require "timeout"

AVAILABLE_MEMES = YAML.load_file("memes.yml")

ALIASED_MEMES = AVAILABLE_MEMES.inject({}) { |h, e| h[e[1][:alias].to_s] = e[0]; h }

ERROR_MESSAGES = {
  "invalid" => "Y U NO PICK A VALID MEME?! But seriously, the meme name you provided is not valid.",
  "tokens" => "Yo dawg, you are missing some url parameters, try harder.",
  "url" => "WAT. That url wasn't an image"
}

MC = ENV["MEMCACHE_SERVERS"] || "localhost:11211"

use Rack::Cache, {
  :verbose => true,
  :metastore => "memcached://#{MC}",
  :entitystore => "memcached://#{MC}"
}

class NotAnImageException < StandardError; end

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

  tokens.shift if tokens.length > 3 && tokens[0] == ""

  url_match = path.match("/(https?:/.*)$")
  if url_match
    # we got a remote url, its go time
    image_url = url_match[1]
    image_url.gsub!(":/", "://")

    redirect "/i_see/what_you_did_there/trollface.jpg" if image_url.include? request.host

    # grab the remote image
    begin
      tempfile = Tempfile.new(["imagegrabber", ".jpg"])
      Timeout::timeout 3 do
        open(image_url) do |url|
          tempfile.write(url.read)
        end
      end

      meme_path = normalize_image tempfile.path
      width = 550
    rescue OpenURI::HTTPError, NotAnImageException, Timeout::Error => e
      puts "EXCEPTION: #{e.inspect} -- #{path}"
      redirect "/?error=url"
    end
  else
    # its using one of the builtin memes
    redirect "/?error=tokens" unless tokens.length == 3

    meme_name = tokens[-1].split(".")[0].downcase
    meme_name = ALIASED_MEMES[meme_name] if ALIASED_MEMES.include?(meme_name)
    redirect "/?error=invalid" unless AVAILABLE_MEMES.include?(meme_name)

    meme_path = File.dirname(__FILE__) + "/public/images/meme/#{meme_name}.jpg"
    width = AVAILABLE_MEMES[meme_name][:width]
  end

  # memeify the text
  top = tokens[0].upcase.gsub("_", " ")
  bottom = tokens[1].upcase.gsub("_", " ")

  # default to a space so that memeify works correctly
  top = " " if top.nil? || top.length == 0

  meme = memeify meme_path, top, bottom, width
  meme.read
end

def memeify memepath, top, bottom, width
  tempfile = Tempfile.new("memeifier", "/tmp/")

  # use imagemagick commands to generate the images
  # commands were largely stolen from https://github.com/vquaiato/memish
  convert top, memepath, tempfile.path, "north", width
  convert bottom, tempfile.path, tempfile.path, "south", width

  tempfile
end

def normalize_image path
  tempfile = Tempfile.new(["normalized", ".jpg"])
  cmd = "convert -resize 600x #{Shellwords.escape(path)} #{tempfile.path}"
  `#{cmd}`
  raise NotAnImageException if $?.to_i > 0
  tempfile.path
end

def convert text, source, destination, location, width
  fontpath = File.dirname(__FILE__) + "/lib/impact.ttf"
  text = Shellwords.escape(text)
  cmd = "convert -fill white -stroke black -strokewidth 2 -background transparent -gravity center -size #{width}x120 -font #{fontpath} -weight Bold caption:\"#{text}\" #{source} +swap -gravity #{location} -composite #{destination}"
  `#{cmd}`
end
