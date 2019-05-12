#!/usr/bin/ruby
# search a tree for all .d files, scan every file for TioPortMixin comments.
# if such comments are found, collect all paragraphs and write them into a mxin file.
# existing mixinfiles will be overwritten
#
# extractmixins.rb <srctree> <mixintree>

require 'find'
require 'fileutils'

if ARGV.length != 2
    puts "usage: extractmixins.rb <srctree> <mixintree>"
    exit 1
end

srctree = ARGV[0];
mixtree = ARGV[1];
puts "srctree   #{srctree}"
puts "mixintree #{mixtree}"

if ! FileTest.directory? srctree
    puts "srctree not a directory"
    exit 1
end
if ! FileTest.directory? mixtree
    puts "mixtree not a directory"
    exit 1
end

#COMMENT_START = /^\(\s*\)\/\/TioPortMixin\>/
COMMENT_START = /^(\s*)\/\/TioPortMixin\b/
COMMENT_END   = /^\s*\/\/TioPortMixinEnd\b/

def append( arr, indent, line )
    if line.length != 0 and line.slice( 0, indent.length ) != indent
        raise "must match the indent of be an empty line"
    elsif line.length == 0
        arr << ""
    else
        arr << line.slice( indent.length, line.length )
    end
    arr
end

def processFile( src, mix )
    #puts "#{src} -> #{mix}"

    indent = 0
    File.open( src, "r") do |infile|
        indent = "";
        content = Array.new
        inmixin = false
        while (line = infile.gets)
            if line =~ COMMENT_START
                indent = $1
                inmixin = true;
            elsif line =~ COMMENT_END
                inmixin = false;
            end
            if inmixin
                content = append( content, indent, line )
            end
        end
        if inmixin
            raise "mixin was not closed in #{src}"
        end
        if content.length > 0
            puts "writing #{mix}"
            FileUtils.mkdir_p( File.dirname( mix ) )
            File.open( mix, "w" ) do |mixfile|
                content.each do |contentline|
                    mixfile << contentline
                end
            end
        end
    end
end

Find.find( srctree ) do |fpath|
    relpath = fpath.slice( srctree.length, fpath.length )
    if FileTest.directory?(fpath)
        if fpath =~ /.*\.svn/
            Find.prune
            next
        end
    else
        unless fpath =~ /\.d$/
            next
        end
        processFile( fpath, mixtree + relpath )
        #FileUtils.cp( fpath, deploy_dir + "/src" + relpath )
    end
end

