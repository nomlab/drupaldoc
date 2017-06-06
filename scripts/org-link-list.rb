#!/usr/bin/env/ruby

require 'net/http'
require 'uri'

class Org
  attr_reader :links

  def initialize(string)
    @links = []
    @lines = []

    string.split(/\n/).each do |line|
      @lines << line
      @links << Link.parse(line)
    end
  end

  def dump
    @lines.each_with_index do |line, index|
      print line
      # size = @links[index].map(&:size).reduce(:+)
      size = nil
      local_org_path = @links[index].map(&:local_org_path).reduce(:+)
      print " (#{size})" if size
      print " (#{local_org_path})" if local_org_path
      print "\n"
    end
  end

  def self.parse(string)
    new(string)
  end

  # [[https://www.drupal.org/docs/8][Drupal 8]]
  class Link
    attr_reader :url, :title

    def initialize(url, title = nil)
      @url, @title = url, title
    end

    def local_org_path
      url = URI.parse(@url)
      return url.path.sub(/^\//, "") + ".org"
    end

    # <div class="column-content-region-inner left-content-inner column-inner panel-panel-inner">
    def size
      url = URI.parse(@url)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      response = http.head(url.path)
      return response.header['Content-Length'].to_i - (39602 - 261)
    end

    def self.parse(line)
      links = []
      line.scan(/\[\[(https?:\/\/[^\]]*)\]\[(.*)\]\]/) do |url, title|
        links << new(url, title)
      end
      return links
    end
  end
end

org = Org.new(gets(nil))
org.dump
