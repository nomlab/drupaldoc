#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'pathname'
require 'fileutils'

class Org
  def initialize(string, topdir = "org")
    @content = string
    @topdir = topdir
  end

  def dump
    @content
  end

  def links_as_local
    links = []
    each_element do |element|
      if element.element_type == :link
        links << element.to_local(@topdir)
      end
    end
    return links
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
    attr_reader :url, :topdir

    def element_type
      :link
    end

    def title
      @title.sub(/\s+\|.*/, "")
    end

    def initialize(url, title = nil, topdir = nil)
      @url, @title, @topdir = url, title, topdir
    end

    def to_s
      return "[[#{@url}][#{title}]]" if @title
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

def create_template(link)
  setupfile = Pathname.new("options/default.org")
  orgdir = Pathname(File.dirname(link.path))

  relative = setupfile.relative_path_from(orgdir)
  lines = []
  lines << "#+TITLE: #{link.title}"
  lines << "#+SETUPFILE: #{relative}"

  FileUtils.mkdir_p(File.dirname(link.full_path))

  File.open(link.full_path, "w") do |file|
    file.puts lines.join("\n")
  end
end

org = Org.new(gets(nil), "org")

File.open("org/index.org", "w") do |file|
  org.each_element do |e|
    if e.element_type == :link
      str = e.to_local(@topdir).to_s
    else
      str = e.to_s
    end
    file.print str
  end
end

org.links_as_local.each do |link|
  next if link.exist?
  puts "* Creating template #{link.path}"
  create_template(link)
end
