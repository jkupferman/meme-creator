#!/usr/bin/env ruby
require "rubygems"
require "sinatra"
require "tempfile"
require "RMagick"

KNOWN_MEMES = Dir.entries(File.dirname(__FILE__) + "/public/images/meme/").map { |i| i.split(".")[0] if i.include?(".jpg") }.compact

ERROR_MESSAGES = {'invalid' => 'Y U NO PICK A VALID MEME?! But seriously, the meme name you provided is not valid.'}

get "/" do
  cache_control :public, :max_age => "300"

  @error = params[:error]
  erb :index
end

get "/*" do
  content_type 'image/jpg'
  cache_control :public, :max_age => "2592000"  # cache for up to a month

  # expects meme in the format /TOP_STRING/BOTTOM_STRING/MEME_NAME.jpg
  tokens = params["splat"][0].split("/")
  tokens.shift if tokens.length > 3
  meme_name = tokens[-1].split(".")[0].downcase
  top = tokens[0].upcase
  bottom = tokens[1].upcase

  redirect "/?error=invalid" unless KNOWN_MEMES.include?(meme_name)

  # default to a space so that memeify works correctly
  top = " " if top.nil? || top.length == 0

  meme = memeify meme_name, top, bottom
  meme.read
end

def memeify meme, top, bottom
  tempfile = Tempfile.new("memeifier", "/tmp/")
  memepath = File.dirname(__FILE__) + "/public/images/meme/#{meme}.jpg"

  # use imagemagick commands to generate the images
  # commands were largely stolen from https://github.com/vquaiato/memish
  convert top, memepath, tempfile.path, "north"
  convert bottom, tempfile.path, tempfile.path, "south"

  tempfile
end

def convert text, source, destination, location
  cmd = "convert -fill white -stroke black -strokewidth 3 -background transparent -gravity center -size 350x -pointsize 56 -font Impact-Bold caption:\"#{text}\" #{source} +swap -gravity #{location} -composite #{destination}"
  result = `#{cmd}`
end
