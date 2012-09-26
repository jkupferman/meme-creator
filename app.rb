#!/usr/bin/env ruby
require "rubygems"
require "sinatra"
require "tempfile"
require "RMagick"

get "/" do
  erb :index
end

get "/meme/:meme_name" do
  content_type 'image/jpg'
  meme_name = params[:meme_name] || "aliens"
  top = params[:top] || ""
  bottom = params[:bottom] || ""

  meme = memeify meme_name, top, bottom
  meme.read
end

def memeify meme, top, bottom
  tempfile = Tempfile.new("memeifier", "/tmp/")
  memepath = File.dirname(__FILE__) + "/public/images/meme/#{meme}.jpg"

  # use imagemagick commands to generate the images
  # commands stolen from https://github.com/vquaiato/memish
  if top
    top_command = "convert -fill white -stroke black -strokewidth 2 -background transparent -gravity center -size 390x60 -font Impact-Normal label:'#{top}' #{memepath} +swap -gravity north -composite #{tempfile.path}"
    result = `#{top_command}`
  end

  if bottom
    bottom_command = "convert -fill white -stroke black -strokewidth 2 -background transparent -gravity center -size 390x60 -font Impact-Normal label:'#{bottom}' #{tempfile.path} +swap -gravity south -composite #{tempfile.path}"
    result = `#{bottom_command}`
  end

  tempfile
end
