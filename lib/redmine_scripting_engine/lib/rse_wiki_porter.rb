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

require 'zip'

module RedmineScriptingEngine
  module Lib
    module RseWikiPorter
      class << self
      
        ##################################################################################
        #
        # Traverses a directory for wiki content to import, markdown or textile
        # 
        #   wiki_scripts/
        #     index.md|index.textile|index.txt
        #     index.1.md|index.1.textile|index.1.txt
        #     index.2.md|index.2.textile|index.2.txt
        #     index.3.md|index.3.textile|index.3.txt
        #     index.….md|index.….textile|index.….txt
        #     …
        #     …
        #     … (any content file as attachment)
        #     
        #       directory_name/
        #         index.md|index.textile
        #         …
        #         …
        #         …
        #         … (any content file as attachment)
        #         
        ##################################################################################
        
        include RedmineScriptingEngine::Lib
        
        # ------------------------------------------------------------------------------ #
        #
        # returns redmine_scripting_engine plugin object
        #
        def plugin
          Redmine::Plugin.registered_plugins[:redmine_scripting_engine]
        end #def
        
        # ------------------------------------------------------------------------------ #
        #
        # returns presets from init.rb
        #
        def preset( key_str )
          plugin.settings[:presets][key_str]
        end #def
        
        # ------------------------------------------------------------------------------ #
        #
        # returns wiki file extension
        #
        def wiki_ext
           preset('wikiexts')[Setting.text_formatting]
        end #def
        
        # ------------------------------------------------------------------------------ #
        #
        # returns wiki directory 
        #
        def wiki_dir
          File.join(plugin.directory, "lib", plugin.id.to_s, "wikis")
        end #def
        
        # ------------------------------------------------------------------------------ #
        #
        # returns all directories in wiki directory 
        #
        def wiki_dirs(dir=wiki_dir)
          Dir.glob(File.join(dir,"*")).select {|f| File.directory? f}.map(&File.method(:realpath))
        end #def
        
        # ------------------------------------------------------------------------------ #
        #
        # returns wiki file in provided directory or nil
        #
        def wiki_file(dir=wiki_dir)
          return nil unless ext = wiki_ext
          Dir.glob(File.join(dir, "index.#{ext}")).select {|f| File.file? f}.map(&File.method(:realpath)).first
        end #def
        
        # ------------------------------------------------------------------------------ #
        #
        # returns wiki version file in provided directory or nil
        #
        def wiki_versions(dir=wiki_dir)
          return nil unless ext = wiki_ext
          paths = Dir.glob(File.join(dir, "index.[0-9]*.#{ext}")).select {|f| File.file? f}.map(&File.method(:realpath))
          paths.map{|path| [File.basename(path)[/(?<=index\.)\d+(?=\.#{ext})/], path]}.sort{|arr1, arr2| arr1[0].to_i <=> arr2[0].to_i}.to_h
        end #def
        
        # ------------------------------------------------------------------------------ #
        #
        # returns all files in provided directory, but index.#{ext} or nil
        #
        def other_files(dir=wiki_dir)
          return nil unless ext = wiki_ext
          paths = Dir.glob(File.join(dir, "**")).select {|f| File.file? f}.map(&File.method(:realpath))
          paths.reject!{|path| path =~ /index.#{ext}|index.[0-9]+.#{ext}/ }
          paths
        end #def
        
        # ------------------------------------------------------------------------------ #
        #
        # imports all files in one wiki directory
        #
        def import(project, options={})
        
          dir    = options[:dir].presence    || wiki_dir
          level  = options[:level].presence  || 0
          parent = options[:parent]
          root   = options[:root]
          
          Rails.logger.info " " * 2 * level + "D: #{File.basename(dir)}"
          
          # safety check: does parent belong to project
          return if parent && parent.project != project
          
          # get project wiki
          unless wiki = project.try(:wiki)
           wiki = Wiki.new(:project => project, :start_page => "Wiki")
           wiki.save
          end
          
          # get all project wiki titles
          titles = wiki.pages.pluck(:title)
          
          # search wiki files
          wf  = wiki_file(dir)
          wfs = wiki_versions(dir)
          
          ################################################################################
          # create page if wiki was found
          ################################################################################
          if wf.present? || wfs.present? #wiki file || wiki_versions
          
          # make title unique and sanitize, may brake wiki links
            title = RseFile.unique_title( titles, File.basename(dir) )
            
          # create wiki page
            page    = WikiPage.new(:wiki => wiki, :parent => parent, :title => title)
            
          end # wf || wfs
          
          ################################################################################
          # import all versions, starting from the lowest index to the highest index
          ################################################################################
          if wfs.present? #wiki_versions
            
            wfs.each do |index, path|
            
              Rails.logger.info " " * (2 * level + 1) + "V: #{File.basename(path)}::#{File.mtime(path)}"
              
              content            = page.content || WikiContent.new(:page => page)
              content.text       = File.open(path, "rt"){|f| f.read}
              content.comments   = ""
              content.author     = User.current
              content.updated_on = File.mtime(path)
              saved = page.save_with_content(content)
              
            end # wfs / wiki_versions
          end #if
          
          ################################################################################
          # load the highest version
          ################################################################################
          if wf.present?
          
              Rails.logger.info " " * (2 * level + 1) + "I: index.#{wiki_ext}::#{File.mtime(wf)}"
              
              content            = page.content || WikiContent.new(:page => page)
              content.text       = File.open(wf, "rt"){|f| f.read}
              content.comments   = ""
              content.author     = User.current
              content.updated_on = File.mtime(wf)
              saved = page.save_with_content(content)
              
          end # wiki_file || wiki_versions
          
          ################################################################################
          # attachments
          ################################################################################
          if page
            
          # search attachments, other than index file
            other_files(dir).each do |file|
             
              Rails.logger.info " " * (2 * level + 1) + "A: #{File.basename(file)}::#{File.mtime(file)}"
              
              bytes    = File.open(file, "rb"){|f| f.read}
              mime     = MimeMagic.by_magic(bytes)
              ext      = Rack::Mime::MIME_TYPES.invert[mime]
              filename = RseFile.sanitize( File.basename(file) )
             
              page.attachments << Attachment.new(
                :file         => bytes,
                :filename     => filename,
                :content_type => mime,
                :author       => User.current,
                :created_on   => File.mtime(file)
              ) if saved
            end # other_files
          
          end #if
          
          ################################################################################
          # dive into directories
          ################################################################################
          wiki_dirs(dir).each do |sdir|
            import(project, :dir => sdir, :parent => page || parent, :level => level+1)
          end
            
        end #def
        
        # ------------------------------------------------------------------------------ #
        #
        # returns all files in one wiki directory
        #
        def export( project, page=nil, history=false, &chunk )
        
          page_id = page && page.id
          
          # get wiki root page for project
          return nil unless wiki_root_page = preestimate( project, page_id )
          
          # create Zip streamer object
          writer = ZipTricks::BlockWrite.new(&chunk)
          
          ZipTricks::Streamer.open(writer) do |zip|
          
          # export wiki_root_page to zip
            export_page( wiki_root_page, zip, wiki_root_page.title, history )
            
          end #ziptricks
          
        end #def
        
        # ------------------------------------------------------------------------------ #
        #
        # returns all files in one wiki directory
        #
        def export_page( wiki_page, zip, dir="", history=false, level=0)
          
          # export all previous page versions?
          if history
          
            # export wiki_page content versions
            wiki_page.content.try(:versions).to_a.each do |version|
              Rails.logger.info " " * (2 * level + 1) + "V: #{wiki_page.title}.#{version.version}::#{version.updated_on}"
              fname = "index.#{version.version}.#{wiki_ext}"
              zip.write_deflated_file(File.join(dir, fname), modification_time:version.updated_on) do |file_writer|
                file_writer << version.text.to_s.encode("UTF-8", universal_newline: true)
              end
            end
          
          # export only current page
          else
          
          # export wiki_page content
          
            Rails.logger.info " " * (2 * level + 1) + "I: #{wiki_page.title}::#{wiki_page.updated_on}"
            fname = "index.#{wiki_ext}"
            zip.write_deflated_file(File.join(dir, fname), modification_time:wiki_page.content.updated_on) do |file_writer|
              file_writer << wiki_page.content.try(:text).to_s.encode("UTF-8", universal_newline: true)
            end
            
          end
          
          # export wiki_page's attachments
          wiki_page.attachments.each do |att|
            Rails.logger.info " " * (2 * level + 1) + "A: #{att.filename}::#{att.created_on}"
            zip.write_deflated_file(File.join(dir, att.filename), modification_time:att.created_on) do |file_writer|
              File.open(att.diskfile, 'rb'){|source| IO.copy_stream(source, file_writer) }
            end
          end
          
          # export wiki_page's children
          wiki_page.children.each do |child_page|
            export_page( child_page, zip, File.join(dir, child_page.title), history, level+1)
          end #def
          
        end #def
        
        # ------------------------------------------------------------------------------ #
        #
        # returns wiki_root_page, unless no content can be expected
        #
        def preestimate( project, page_id=nil)
        
          # return, unless project's wiki_pages are visible
          return nil unless User.current.allowed_to?(:view_wiki_pages, project)
          
          # return, unless Setting.text_formatting is known
          return nil unless wiki_ext
          
          # if page_id is given, find the title of that page
          if page_id
            begin
              wiki_page = WikiPage.find(page_id)
            rescue ActiveRecord::RecordNotFound
              wiki_page = nil
            end
            # return, unless wiki_page is found
            return nil unless wiki_root = wiki_page.try(:title)
            
          else
          #if page_is is nil, try to find configured page
            # return, unless wiki_root is set
            return nil unless wiki_root = Setting["plugin_redmine_scripting_engine"]["wikiscripts_root"]
          end
          
          # find wikiscript root page for that project by title in project, not by id to avoid page sniffing
          return nil unless wiki_root_page = Wiki.find_page(wiki_root, :project => project)
          
          wiki_root_page
          
        end #def
        
      end #class
    end #module
  end #module
end #module
