#!/usr/bin/env ruby
require "rubygems"
require "sinatra"
require "tempfile"
require "RMagick"

KNOWN_MEMES =  Dir.entries(File.dirname(__FILE__) + "/public/images/meme/").map { |i| i.split(".")[0] if i.include?(".jpg") }.compact

get "/" do
  cache_control :public, :max_age => "300"

  erb :index
end

get "/*" do
  content_type 'image/jpg'
  cache_control :public, :max_age => "2592000"  # cache for up to a month

  # expects meme in the format /meme/TOP_STRING/BOTTOM_STRING/MEME_NAME.jpg
  tokens = params["splat"][0].split("/")
  tokens.shift if tokens.length > 3
  meme_name = tokens[-1].split(".")[0].downcase || "aliens"
  top = tokens[0]
  bottom = tokens[1]

  # default to a space so that memeify works correctly
  top = " " if top.nil? || top.length == 0

  meme = memeify meme_name, top, bottom
  meme.read
end

def memeify meme, top, bottom
  tempfile = Tempfile.new("memeifier", "/tmp/")
  memepath = File.dirname(__FILE__) + "/public/images/meme/#{meme}.jpg"

  # use imagemagick commands to generate the images
  # commands stolen from https://github.com/vquaiato/memish
  if top
    top_command = "convert -fill white -stroke black -strokewidth 2 -background transparent -gravity center -size 390x60 -font Impact-Bold label:'#{top}' #{memepath} +swap -gravity north -composite #{tempfile.path}"
    result = `#{top_command}`
  end

  if bottom
    bottom_command = "convert -fill white -stroke black -strokewidth 2 -background transparent -gravity center -size 390x60 -font Impact-Bold label:'#{bottom}' #{tempfile.path} +swap -gravity south -composite #{tempfile.path}"
    result = `#{bottom_command}`
  end

  tempfile
end
