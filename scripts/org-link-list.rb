#!/usr/bin/env/ruby

require 'net/http'
require 'uri'

class Org
  attr_reader :links

  def initialize(string)
    @content = string
  end

  def dump
    @content.split(/\n/).each do |line|
      links = Link.parse(line)

      print line
      # size = links[index].map(&:size).reduce(:+)
      size = nil
      local_org_path = links[index].map(&:local_org_path).reduce(:+)
      print " (#{size})" if size
      print " (#{local_org_path})" if local_org_path
      print "\n"
    end
  end

  class Link
    attr_reader :url, :title

    def initialize(url, title = nil)
      @url, @title = url, title
    end

    def local_org_path
      url = URI.parse(@url)
      return url.path.sub(/^\//, "") + ".org"
    end

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
