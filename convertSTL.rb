#!/usr/bin/env ruby
# convertSTL.rb - Converts STL files between binary and ASCII encoding
# by Chris Polis
#
# This script detects which encoding the stl file is in and converts it to
#  the opposite encoding and saves the file as *-ascii.stl or *-binary.stl.
#  I wrote this script to save disk space and bandwidth when using stl files. 
# 
# USAGE: 
#  $ ruby convertSTL.rb [filename(s) of .stl to be converted]
#  or 'chmod +x' and run as ./convertSTL.rb
#
#  note: path wildcards, (e.g.: "*.stl") are supported and all matching 
#        files will be converted


# Helper methods
require 'fileutils'
class Float
  def to_sn # to scientific notation
    "%E" % self
  end

  def self.from_sn str # generate a float from scientific notation
    ("%f" % str).to_f
  end
end

# Pass in filename as only argument
if ARGV.size == 0 
  puts "Usage: ./converSTL.rb [stl filename]"
  exit
end

begin
  # Read all files matching arg, "foo.stl", "*.stl", "../stl/*", etc...
  ARGV.each do |originalFilename|
    original = File.new(originalFilename, "r")
    originalFoldername = File.dirname(originalFilename)
    originalBasename = File.basename(originalFilename)

    # Read first line - check binary or ASCII
    tempLine = original.gets
    if tempLine.start_with? "solid"
      FileUtils.mkdir_p("#{originalFoldername}/output-binary")
      outFilename = originalFilename.sub(/#{originalBasename}/i, 'output-binary/binary-'+originalBasename) 
      puts "#{originalFilename} is in ASCII format, converting to BINARY: #{outFilename}"
      outFile = File.new(outFilename, "w")
      outFile.write("\0" * 80) # 80 bit header - ignored
      outFile.write("FFFF")   # 4 bit integer # of triangles - filled later
      triCount = 0
  
      # ASCII STL format (from Wikipedia):
      # solid name(optional)
      #
      # [foreach triangle]
      # facet normal ni nj nk
      # outer loop
      # vertex v1x v1y v1z
      # vertex v2x v2y v2z
      # vertex v3x v3y v3z
      # endloop
      # endfacet
      # endsolid name(optional)
  
      while temp = original.gets
        next if temp =~ /^\s*$/ or temp.include? 'endsolid' # ignore whitespace
        temp.sub! /facet normal/, ''
        normal = temp.split(' ').map{ |num| Float.from_sn num }
        triCount += 1
        temp = original.gets # 'outer loop'
  
        temp = original.gets
        vertexA = temp.sub(/vertex/, '').split(' ').map{ |num| Float.from_sn num }
        temp = original.gets
        vertexB = temp.sub(/vertex/, '').split(' ').map{ |num| Float.from_sn num }
        temp = original.gets
        vertexC = temp.sub(/vertex/, '').split(' ').map{ |num| Float.from_sn num }
  
        temp = original.gets # 'endsolid'
        temp = original.gets # 'endfacet'
  
        outFile.write(normal.pack("FFF"))
        outFile.write(vertexA.pack("FFF"))
        outFile.write(vertexB.pack("FFF"))
        outFile.write(vertexC.pack("FFF"))
        outFile.write("\0\0")
      end
      outFile.seek(80, IO::SEEK_SET)
      outFile.write([ triCount ].pack("V"))
      outFile.close
  
    else
      FileUtils.mkdir_p("#{originalFoldername}/output-ascii")
      outFilename = originalFilename.sub(/#{originalBasename}/i, 'output-ascii/ascii-'+originalBasename) 
      puts "#{originalFilename} is in BINARY format, converting to ASCII: #{outFilename}"
      outFile = File.new(outFilename, "w") 
      outFile.write("solid \n")
  
      # Binary STL format (from Wikipedia):
      # UINT8[80] – Header
      # UINT32 – Number of triangles
      # 
      # foreach triangle
      # REAL32[3] – Normal vector
      # REAL32[3] – Vertex 1
      # REAL32[3] – Vertex 2
      # REAL32[3] – Vertex 3
      # UINT16 – Attribute byte count
      # end
      original.seek(80, IO::SEEK_SET)
      triCount = original.read(4).unpack('V')[0]
      triCount.times do |triNdx|
        normal = original.read(12).unpack('FFF')
        vertexA = original.read(12).unpack('FFF')
        vertexB = original.read(12).unpack('FFF')
        vertexC = original.read(12).unpack('FFF')
        original.seek(2, IO::SEEK_CUR)
  
        outFile.write("  facet normal #{normal[0].to_sn} #{normal[1].to_sn} #{normal[2].to_sn}\n")
        outFile.write("    outer loop\n")
        outFile.write("      vertex #{vertexA[0].to_sn} #{vertexA[1].to_sn} #{vertexA[2].to_sn}\n")
        outFile.write("      vertex #{vertexB[0].to_sn} #{vertexB[1].to_sn} #{vertexB[2].to_sn}\n")
        outFile.write("      vertex #{vertexC[0].to_sn} #{vertexC[1].to_sn} #{vertexC[2].to_sn}\n")
        outFile.write("    endloop\n")
        outFile.write("  endfacet\n")
      end
  
      outFile.write("endsolid \n")
      outFile.close
    end
    original.close
  end
rescue => error
  puts "Error: #{error}"
end
