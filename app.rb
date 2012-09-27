#!/usr/bin/env ruby
require "rubygems"
require "sinatra"
require "tempfile"
require "RMagick"

AVAILABLE_MEMES = {
  "aliensguy" => {:name => "Aliens Guy", :width => 540},
  "condescendingwonka" => {:name => "Condescending Wonka", :width => 400},
  "ermahgerd" => {:name => "Ermahgerd", :width => 400},
  "firstworldproblems" => {:name => "First World Problems", :width => 540},
  "futuramafry" => {:name => "Futurama Fry", :width => 570},
  "grumpycat" => {:name => "Grumpy Cat", :width => 380},
  "overlyattachedgirlfriend" => {:name => "Overly Attached Girlfriend", :width => 470},
  "scumbagsteve" => {:name => "Scumbag Steve", :width => 580},
  "successkid" => {:name => "Success Kid", :width => 480},
  "xzibit" => {:name => "Xzibit", :width => 740},
  "yunoguy" => {:name => "Y U NO GUY", :width => 470},
}

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
  cmd = "convert -fill white -stroke black -strokewidth 2 -background transparent -gravity center -size #{width}x -pointsize 56 -font #{fontpath} -weight Bold caption:\"#{text}\" #{source} +swap -gravity #{location} -composite #{destination}"
  result = `#{cmd}`
end
