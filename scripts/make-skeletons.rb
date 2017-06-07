#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'pathname'


class Org
  attr_reader :links

  def initialize(string, topdir = "org")
    @content = string
    @topdir = topdir
  end

  def dump
    each_element do |element|
      if element.element_type == :link
        element = element.to_local(@topdir)
        create_template(element) unless element.exist?
      end

      # print element.to_s

      # size = links[index].map(&:size).reduce(:+)
      # local_org_path = links[index].map(&:local_org_path).reduce(:+)
      # print " (#{size})" if size
      # print " (#{local_org_path})" if local_org_path
    end
  end

  # split at links
  def each_element
    strexp = "([^\\]]+)"

    @content.split(/\n/).each do |line|
      elements = []

      while line.length > 0
        if line =~ /\[\[#{strexp}\]\[#{strexp}\]\]/
          url, title = $1, $2
        elsif line =~ /\[#{strexp}\]/
          url, title = $1, nil
        else
          url, title = nil, nil
        end

        if url
          elements << PlainString.new($`) if $`
          elements << Link.create(url, title, @topdir)
          line = $'
        else
          elements << PlainString.new(line)
          line = ""
        end
      end
      elements << PlainString.new("\n")
      elements.each do |element|
        yield element
      end
    end
  end

  private

  def create_template(local_link)
    STDERR.puts "Create #{local_link.path}"
    tmp = OrgTemplate.new(local_link)
    STDERR.puts "=> #{tmp.full_path}"
    puts tmp.to_s
  end
end

class OrgTemplate

  def initialize(local_link)
    @local_link = local_link

    if local_link.exist?
      @content = File.read(local_link.full_path)
    else
      @content = make_template(local_link)
    end
  end

  def to_s
    @content
  end

  def full_path
    @local_link.full_path
  end

  def path
    @local_link.path
  end

  private

  def make_template(local_link)
    setupfile = Pathname.new("options/default.org")
    orgdir = Pathname(File.dirname(local_link.path))

    relative = setupfile.relative_path_from(orgdir)
    lines = []
    lines << "#+TITLE: #{local_link.title}"
    lines << "#+SETUPFILE: #{relative}\n"
    lines.join("\n")
  end
end

class PlainString < String
  def element_type
    :plain_string
  end
end

class Link
  def self.create(url, title = nil, topdir = nil)
    if url =~ /^https?:/
      Link::Remote.new(url, title)
    else
      Link::Local.new(url, title, topdir)
    end
  end

  class Base
    attr_reader :url, :title, :topdir

    def element_type
      :link
    end

    def initialize(url, title = nil, topdir = nil)
      @url, @title, @topdir = url, title, topdir
    end

    def to_s
      return "[[#{@url}][#{@title}]" if @title
      return "[#{@url}]"
    end

    def remote?
      @url =~ /^https?:/
    end

    def local?
      !remote?
    end
  end

  class Remote < Base
    def to_local(topdir)
      local_url = "file:" + URI.parse(@url).path.sub(/^\//, "") + ".org"
      Link::Local.new(local_url, @title, topdir)
    end

    def exist?
      fetch_head.code =~ "2.."
    end

    def path
      URI.parse(@url).path
    end

    def full_path
      path
    end

    def size
      fetch_head.header['Content-Length'].to_i - 40000 # FIXME
    end

    private

    def fetch_head
      url = URI.parse(@url)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      return http.head(url.path)
    end
  end

  class Local < Base
    def to_local(topdir)
      Link::Local.new(@url, @title, topdir)
    end

    def exist?
      File.exist?(full_path)
    end

    def path
      if @url =~ /^file:(.*)/
        $1
      else
        nil
      end
    end

    def full_path
      path && File.expand_path(path, topdir)
    end

    def size
      FileTest.size(full_path)
    end
  end
end



org = Org.new(gets(nil), "org")
org.dump
