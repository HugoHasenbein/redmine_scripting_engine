# encoding: utf-8
#
# Redmine plugin to execute untrusted code
#
# Copyright © 2021 Stephan Wenzel <stephan.wenzel@drwpatent.de>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

require 'fileutils'

module RedmineScriptingEngine
  module Lib
    module RseFile
      class << self
        
        # ------------------------------------------------------------------------------ #
        #
        def create_filename( filename, mime_type, options={} )
          extension = File.extname(filename.to_s)
          basename  = File.basename(filename.to_s, extension)
          extension = Rack::Mime::MIME_TYPES.invert[mime_type.to_s].presence.to_s if extension.blank?
          basename  = mime_type.to_s =~ /image/ ? "image" : "file" if basename.blank?
          sanitize( "#{basename}#{extension}", options)
        end #def
        
        #---------------------------------------------------------------------------------
        # sanitize
        #
        # sanitize(filename, , options = {})
        # returns sanitized filename(string)
        #  
        #  options:
        # :ignore_delimiters => true
        #         true:
        #         will accept names with directory delimiters 
        #         and will replace delimiters with "_"
        #         else
        #         will chop off directory names
        #        
        #---------------------------------------------------------------------------------
        def sanitize( filename, options = {} )
          # Bad as defined by wikipedia: https://en.wikipedia.org/wiki/Filename#Reserved_characters_and_words
          # Also have to escape the backslash, ampersand, ", ', and ;
          _bad_chars = /\/|\\|\?|%|\*|:|\|\"|\'|\<|\>| |;|&/
          _filename  = RseText.to_utf8(filename.to_s.dup) # in case filename is nil
          _filename  = _filename.gsub(_bad_chars, '_') if options[:ignore_delimiters]
          _filename  = File.basename( _filename ) 
          _filename  = _filename.presence || "noname"
          _extension = File.extname(  _filename)
          _filestem  = File.basename( _filename, _extension)
          # limit maximum length of filename to 260 characters
          _extension = _extension[0..255]      # limit extension length
          _fslength  = 260 - _extension.length # limit basename accordingly
          _filename  = "#{_filestem[0.._fslength]}#{_extension}"
          _filename.gsub(_bad_chars, '_')
        end #def
        
        # ------------------------------------------------------------------------------ #
        # unique_filename( filenames(array), filename(string) )
        # returns filename, which is unique to filenames-array,
        # whereby extensions are kept
        #
        def unique_filename( filenames, filename, index=2 )
        
          if filenames.any? {|f| f == filename }
          
            #######################################################################
            #  get extension, i.e. '.txt'                                         #
            #######################################################################
            extname = File.extname(filename) 
            
            #######################################################################
            #  is extension an index?, i.e. '.2'                                  #
            #######################################################################
            if !!(extname =~ /\A\.\d+\z/) # is extension already a number?
              basname = File.basename(filename, extname) # get the basename 
              extname = "" # new index will replace index extension
              
            elsif extname.blank?
            #######################################################################
            #  no extension                                                       #
            #######################################################################
              basname = filename
              extname = "" #extname is already blank
            else
            #######################################################################
            #  extension exists and is NOT an index, i.e. '.2'                    #
            #######################################################################
              tmpname = File.basename(filename, extname) # leave a basename with a possible index counter, i.e. 'text.0'
              indname = File.extname(tmpname) # get secondary extension filename, i.e. '.0' from text.0.txt (if at all)
              if !!(indname =~ /\A\.\d+\z/) # is secondary extension  a number?
                basname = File.basename(tmpname, indname) # get the eventual basename, i.e 'text'
              else
                basname = tmpname
              end
            end #def
            
            newname = unique_filename( filenames, "#{basname}.#{index}#{extname}", index + 1 )
          else
            return filename
          end #if 
        end #def
        
        # ------------------------------------------------------------------------------ #
        # make_filenames_unique( filenames(array) )
        # returns array of filenames, with each name unique
        # whereby extensions are kept
        #
        def make_filenames_unique( filenames )
        
           new_filenames = []
           # all but the first name must be unique_filename
           filenames.each do |filename|
             new_filenames << unique_filename( new_filenames, filename )
           end #each
           new_filenames
        end#def
        
        #---------------------------------------------------------------------------------
        # sanitize wiki title
        #
        #
        def sanitize_wiki( title, options = {} )
          # Bad as defined by wiki_page validates_format_of :title, :with => /\A[^,\.\/\?\;\|\s]*\z/
          _bad_chars = /,|\.|\/|\?|\;|\|\s/
          _title     = RseText.to_utf8(title.to_s.dup) # in case title is nil
          _title     = _title.gsub(_bad_chars, '_')
          _title     = _title.presence || "noname"
          _title     = _title[0..250]
        end #def
        
        # ------------------------------------------------------------------------------ #
        # unique_title( titles(array), title(string) )
        # returns title, which is unique to titles-array,
        # whereby extensions are kept
        #
        def unique_title( titles, title, index=2 )
        
          if titles.any? {|f| f == title }
          
            #######################################################################
            #  get extension, i.e. '1'                                            #
            #######################################################################
            extname = title.scan(/\d+\z/).first
            
            #######################################################################
            #  is extension an index?, i.e. '.2'                                  #
            #######################################################################
            if extname # is extension already a number?
              basname = title.scan(/.*?(?=#{extname}\z)/).first # get the basename 
              extname = "" # new index will replace index extension
              
            elsif extname.blank?
            #######################################################################
            #  no extension                                                       #
            #######################################################################
              basname = title
              extname = "" #extname is already blank
            else
            #######################################################################
            #  extension exists and is NOT an index, i.e. '.2'                    #
            #######################################################################
              tmpname = title.scan(/.*?(?=#{extname}\z)/).first # leave a basename with a possible index counter, i.e. 'text.0'
              indname = tmpname.scan(/\d+\z/).first # get secondary extension title, i.e. '.0' from text.0.txt (if at all)
              if !!(indname =~ /\A\_\d+\z/) # is secondary extension  a number?
                basname = tmpname.scan(/.*?(?=#{indname}\z)/).first # get the eventual basename, i.e 'text'
              else
                basname = tmpname
              end
            end #def
            
            newname = unique_title( titles, "#{basname}_#{index}#{extname}", index + 1 )
          else
            return title
          end #if 
        end #def
        
        # ------------------------------------------------------------------------------ #
        # make_titles_unique( titles(array) )
        # returns array of titles, with each name unique
        # whereby extensions are kept
        #
        def make_titles_unique( titles )
        
           new_titles = []
           # all but the first name must be unique_title
           titles.each do |title|
             new_titles << unique_title( new_titles, title )
           end #each
           new_titles
        end#def
        
        # ------------------------------------------------------------------------------ #
        # sanitize_subdir(subdir, dir)
        # returns sanitized subdir(string), which does not expand higher than dir(string)
        #        
        def sanitize_subdir( subdir, dir )
          subpath  = Pathname.new( subdir )
          path     = Pathname.new( dir )
          expanded = subpath.expand_path( path )
          relative = expanded.relative_path_from( path )
          #puts relative.to_path
          subdir unless !!(relative.to_path =~ /\A\.\./)
        end #def
        
        #-----------------------------------------------------------------------------------
        # get directory, if it does not exist, create directory
        #-----------------------------------------------------------------------------------
        def directory( subdir, dir=nil )
          subdir = sanitize_subdir(subdir, dir) if dir
          FileUtils.mkdir_p subdir if subdir && !File.exists?(subdir)
          subdir
        end #def
        
        #-----------------------------------------------------------------------------------
        # get directory, if it does not exist, create directory
        #-----------------------------------------------------------------------------------
        def file_directory( filepath, dir=nil )
          filedir = File.dirname( filepath )
          directory( filedir, dir=nil )
        end #def
        
      end #class
    end #module
  end #module
end #module
