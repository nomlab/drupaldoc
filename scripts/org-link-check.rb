#!/usr/bin/env ruby

EXCLUDE_PATTERN = /attic/

def list_all_files(topdir, glob, exclude_pattern)
  Dir.chdir(topdir) do
    Dir[glob].reject do |fn|
      File.directory?(fn) or
        fn =~ exclude_pattern
    end
  end
end

def list_all_links_in_org(filename)
  links = []
  File.open(filename).each do |line|
    links += line.scan(/file:([^\]\s]+)/).flatten
    links << $1 if line =~ /^\s*#\+begin_src.*\s+:file\s+([^\s]+)/i
    links << $1 if line =~ /^#\+SETUPFILE:\s+([^\s]+)/i
  end
  return links
end

def stale_link_check
  list_all_files(".", "**/*.org", EXCLUDE_PATTERN).each do |fn|
    puts "   + #{fn}:"
    list_all_links_in_org(fn).each do |link|
      status = File.exists?(link) ? "" : "**************** NOT FOUND!!"
      puts "     + #{link} #{status}"
    end
  end
end

def orphan_file_check
  files = list_all_files(".", "**/*", EXCLUDE_PATTERN)
  list_all_files(".", "**/*.org", EXCLUDE_PATTERN).each do |fn|
    list_all_links_in_org(fn).each do |link|
      files.reject!{|fn| fn == link}
    end
  end
  files.each do |fn|
    puts "   + #{fn}"
  end
end

if not ARGV[0]
  STDERR.print "Usage: #{$0} top_directory\n"
  exit 1
end

topdir = ARGV[0]
Dir.chdir(topdir)

puts "* Stale link check:"
stale_link_check

puts "* Orphan file list (not linked from anywhere):"
orphan_file_check
