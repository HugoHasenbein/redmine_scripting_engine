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

module RedmineScriptingEngine
  module Lib
    module RseWikiScript
      
      WILDCARD = "All".freeze
      EXPRFLAG = "*".freeze
      HEADINGS = ["class", "status", "title"].freeze
        
      class << self
      
        class_attribute :wikiscripts_key, :default => SecureRandom.uuid # used as a key for caching
        
        # ----------------------------------------------------------------------------------- #
        def invalidate_wikiscripts_key
          #
          # cache is invalidated
          # 
          #   - on save/destroy a wikipage if wikipage itself or its ancestors contain
          #     the configured "wikiscripts" page
          #     
          #   - on save/destroy a wikicontent if its wikipage itself or its wikipage's 
          #     ancestors contain the configured "wikiscripts" page
          #     
          #   - on changing roles/permissions
          #     
          #   - on changing plugin settings
          #
          # cache invalidation is done in 
          #   - wiki_page_patch, 
          #   - role_patch, 
          #   - wiki_content_patch
          #   - setting_patch
          #
          self.wikiscripts_key = SecureRandom.uuid
        end #def
            
        include RedmineScriptingEngine::Lib
        
        # ----------------------------------------------------------------------------------- #
        #
        # finds wikiscripts, which match all objects
        #
        def find_for( objects, options={}  )
        
          #
          # create one option hash for each combination of properties, unique them
          #
          params_collection = objects.map do |object| 
            options.merge(
              :project       => object.project,
              :class         => object.class.name,
              :status        => expand_statuses(object) # expand statuses
            )
          end.uniq
          
          
          #
          # find wikiscripts for all unique object_params combinations
          #
          wikiscripts = []
          params_collection.each do |params|
            project      = params.delete(:project)
            wikiscripts += scripts( project, params )
          end
          wikiscripts.uniq! # will delete repeated headings as well
          wikiscripts = wikiscripts.to_hashes
          
          #
          # now select those wikiscripts by name, 
          # which match all params in params_collection
          #
          wikiscripts.select! do |wikiscript| 
            params_collection.all? do |params| 
             (wikiscript[:class].split(/ /)  & [params[:class ], WILDCARD].flatten).present? &&
             (wikiscript[:status].split(/ /) & [params[:status], WILDCARD].flatten).present?
            end
          end
          
          redmine_scripts = []
          wikiscripts.each do |wikiscript|
            params   = wikiscript.delete(:params) 
            redmine_scripts << RedmineScript.new(wikiscript.merge(params))
          end
          
          redmine_scripts
        end #def
        
        # ----------------------------------------------------------------------------------- #
        #
        # finds wikiscripts, which matches class
        #
        # required options :project, :class, :status
        #
        def find( klass, options={}  )
          
          #
          # find wikiscripts for klass
          #
          project      = options.delete(:project)
          wikiscripts  = scripts( project, options.merge(:class => klass) ).to_hashes
          
          #
          # now select those wikiscripts by name, 
          # which match all params in options
          #
          wikiscripts.select! do |wikiscript| 
            (wikiscript[:class].split(/ /)  & [         klass  , WILDCARD].flatten).present? &&
            (wikiscript[:status].split(/ /) & [options[:status], WILDCARD].flatten).present?
          end
          
          redmine_scripts = []
          wikiscripts.each do |wikiscript|
            params   = wikiscript.delete(:params) 
            redmine_scripts << RedmineScript.new(wikiscript.merge(params))
          end
          redmine_scripts
        end #def
        
        # ----------------------------------------------------------------------------------- #
        #
        # find cached wikiscripts for class
        #
        def class_wikiscripts( klass, options={} )
          md5 = Digest::MD5.hexdigest(Marshal::dump(options.sort_by{ |key,_| key }))
          Rails.cache.fetch("#{wikiscripts_key}/class_wikiscripts/#{klass}/#{md5}", expires_in: 12.hours) do
            find( klass, options )
          end
        end #def
        
        # ----------------------------------------------------------------------------------- #
        #
        # find wikiscripts for project
        #
        def project_wikiscripts( project )
          wikiscripts  = scripts( project ).to_hashes
          redmine_scripts = []
          wikiscripts.each do |wikiscript|
            params   = wikiscript.delete(:params) 
            redmine_scripts << RedmineScript.new(wikiscript.merge(params))
          end
          redmine_scripts
        end #def
        
        
        # ----------------------------------------------------------------------------------- #
        #
        # creates a table of all wikiscripts, including inherited content
        #    pages must be visible
        #    pages must be protected
        # from ancestor projects, 
        # limit search by providing :title (String, Array), 
        #                           :class (String, Array), 
        #                           :status (String, Array)
        #
        def scripts( project, options={} )
          
          wikiscripts = hash_tree
          
          # define wiki_root and return, if not set
          wiki_root = Setting["plugin_redmine_scripting_engine"]["wikiscripts_root"].presence
          return [[:title, :class, :status, :params]] unless wiki_root
          
          # define projects to search
          inherit   = Setting["plugin_redmine_scripting_engine"]["inherit_wikiscripts"].to_i > 0
          projects  = inherit ? project.try(:self_and_ancestors).to_a : [project].compact
          
          # run through projects, start at farest ancestor
          projects.each do |ancestor|
          
            # filter out projects not visible to user
            next unless ancestor.visible?
            
            # find wikiscript root page for that project
            next unless wiki_root_page = Wiki.find_page( wiki_root, :project => ancestor )
            
            # filter out wiki pages not visible to user
            next unless wiki_root_page.visible?
            
            # get descendants of wiki root page
            wiki_pages = wiki_root_page.descendants
            
            # run through wiki_pages
            wiki_pages.each do |page|
            
              # filter out wiki pages not visible to user
              next unless page.visible?
              
              # filter out wiki pages not protected
              next unless page.protected?
              
              # get script title, if specific one was searched, neglect other pages
              title    = RseWikiScan.page_titles(    page ).first
              next if title.blank?
              next if options[:title].present? && ([title] & [options[:title], WILDCARD].flatten).blank?
              
              # get klasses
              klasses  = RseWikiScan.section_words(  page, "Class"  ).presence || [WILDCARD]
              klasses  = expand_classes(klasses) # expand STI classes
              next if options[:class].present? && (klasses & [options[:class], WILDCARD].flatten).blank?
              
              # get statuses
              statuses = RseWikiScan.section_words(  page, "Status" ).presence || [WILDCARD]
              next if options[:status].present? && (statuses & [options[:status], WILDCARD].flatten).blank?
              
              # get script permission requirements
              permission = RseWikiScan.section_words( page, "Permission" )
              
              # get specific parameters
              params     = RseWikiScan.section_words( page, "Parameter" )
              
              # get script properties 
              danger     = params.map(&:downcase).include?('danger') || params.map(&:downcase).include?('red')
              next if options.key?(:danger) && options[:danger] != danger
              
              # get modal
              modal      = RseWikiScan.section_text(  page, "Modal" )
              
              # eventually, get script
              script     = RseWikiScan.section_code(  page, "Script" )
              
              # eventually, get script type
              type       = RseWikiScan.code_type(     page, "Script" )
              
              # eventually, get script mime
              mime       = RseWikiScan.section_words( page, "Mime" ).first.presence
              
              # save and possibly override wiki_page parameters
              wikiscripts[title][klasses.join(" ")][statuses.join(" ")] = [{
                :project    => ancestor, 
                :author_id  => page.content.author.id,
                :permission => permission,
                :page_id    => page.id, 
                :danger     => danger,
                :params     => params,
                :editable   => page.editable_by?(User.current),
                :script     => script,
                :modal      => modal,
                :type       => type,
                :mime       => mime
              }]
            end #wiki_pages
          end #projects
          # the call to select{|line| line[-1][:script].present?} is somewhat uggly: it filters out empty scripts
          wikiscripts.expand.unshift([:title, :class, :status, :params]).select{|line| line[-1].is_a?(Symbol) || line[-1][:script].present?}
        end #def
        
        # ----------------------------------------------------------------------------------- #
        #
        # loads a wikiscripts tree
        def library_path(project, type)
        
          # define array of libs
          libs = []
          
          # return nil, unless project is given
          return libs unless project
          
          section_name = RSE_LIBRARY_SECTION[type]
          return libs unless section_name
          
          # define wiki_root and return, if not set
          wiki_root = Setting["plugin_redmine_scripting_engine"]["wikiscripts_root"].presence
          return libs unless wiki_root
          
          # define projects to search
          inherit   = Setting["plugin_redmine_scripting_engine"]["inherit_wikiscripts"].to_i > 0
          projects  = inherit ? project.try(:self_and_ancestors).to_a : [project].compact
          
          # run through projects, start at farest ancestor
          projects.each do |ancestor|
          
            # filter out projects not visible to user
            next unless ancestor.visible?
            
            # find wikiscript root page for that project
            next unless wiki_root_page = Wiki.find_page( wiki_root, :project => ancestor )
            
            # filter out wiki pages not visible to user
            next unless wiki_root_page.visible?
            
            # check if lib is available
            lib = RseWikiScan.section_code(  wiki_root_page, section_name )
            next unless lib.present?
            
            # filter out wiki pages not protected
            libs << [ancestor.name, wiki_root_page.protected?]
            
          end #def
          
          libs
          
        end #def
        
        # ----------------------------------------------------------------------------------- #
        #
        # loads a library code ancestry from wiki_root_page
        def libraries(project, type)
          
          # define array of libs
          libs = []
          
          # get section name for required code, give up, if it does not exist
          section_name = RSE_LIBRARY_SECTION[type]
          return libs unless section_name
          
          # define wiki_root and return, if not set
          wiki_root = Setting["plugin_redmine_scripting_engine"]["wikiscripts_root"].presence
          return libs unless wiki_root
          
          # define projects to search
          inherit   = Setting["plugin_redmine_scripting_engine"]["inherit_wikiscripts"].to_i > 0
          projects  = inherit ? project.try(:self_and_ancestors).to_a : [project].compact
          
          # run through projects, start at farest ancestor
          projects.each do |ancestor|
          
            # filter out projects not visible to user
            next unless ancestor.visible?
            
            # find wikiscript root page for that project
            next unless wiki_root_page = Wiki.find_page( wiki_root, :project => ancestor )
            
            # filter out wiki pages not visible to user
            next unless wiki_root_page.visible?
            
            # filter out wiki pages not protected
            next unless wiki_root_page.protected?
            
            # eventually, get script
           libs << [ancestor, RseWikiScan.section_code( wiki_root_page, section_name )]
            
          end #projects
          
          libs
          
        end #def
        
        # ----------------------------------------------------------------------------------- #
        #
        # find cached wikiscript libs for project
        #
        def wikiscript_libs( project, type )
          Rails.cache.fetch("#{wikiscripts_key}/wikiscript_libs/#{project.try(:identifier)}/#{type}", expires_in: 12.hours) do
            libraries( project, type )
          end
        end #def
          
        # ----------------------------------------------------------------------------------- #
        #
        # compile takes a wikipage and turns it into a redmine_script
        #
        def compile( page )
          RedmineScript.compile( page )
        end #def
        
        ##################################################################################
        # expand_classes: called i.a. from RedmineScript
        ##################################################################################
        def expand_classes( arry )
          arry.map{|item| RseClassFactory.descendant_classes(item) }.flatten.uniq
        end #def
        
        ##################################################################################
        #
        # Private functions
        #
        ##################################################################################
        private
        
        ##################################################################################
        # basics
        ##################################################################################
        def hash_tree
          Hash.new do |hash, key|
            hash[key] = hash_tree
          end
        end #def
        
        ##################################################################################
        # expand_statuses
        ##################################################################################
        def expand_statuses(object)
          object_status  = []
          object_status << object.status.to_s if object.respond_to?(:status)
          object_status << "closed"           if object.try(:status).try(:is_closed?)
          object_status << "open"             if object.respond_to?(:closed?) && !object.closed?
          object_status << "active"           if object.try(:active?)
          object_status << "inactive"         if object.respond_to?(:active?)  && !object.active?
          object_status += object.events      if object.respond_to?(:events)
          object_status += object.roles       if object.respond_to?(:roles)
          object_status << WILDCARD
          object_status.compact
        end #def
        
        ##################################################################################
        #
        # match_list
        #
        # first character of expression IS EXPRFLAG (f.i. '*' )
        #
        #        words in expression beginning with - must not be present (bad words)
        #        words in expression beginning with | may      be present (may words)
        #        words in expression beginning with + must     be present (must words)
        #        WILCARD matches, unless must words or bad words are provided
        #        words without modifier, except WILDCARD are neglected
        #       
        # first character of expression IS NOT EXPRFLAG (f.i. '*' )
        # 
        #        any word in expression found in list => match
        #        WILDCARD in expression always matches
        #        
        ##################################################################################
        def match_list(expression, list)
        
          if expression.to_s.match?(/\A#{Regexp.escape EXPRFLAG}/)
            #
            # this is a regularexpression
            #
            
            all_words   = expression[1..-1].split(/\ /).select(&:present?).map(&:squish)
            may_words   = all_words.select{|s| s =~ /\A\|/  }.map{|s| s[1..-1]}
            bad_words   = all_words.select{|s| s =~ /\A\-/  }.map{|s| s[1..-1]}
            must_words  = all_words.select{|s| s =~ /\A\+/  }.map{|s| s[1..-1]}
            
            ((all_words.include? WILDCARD ) || 
             (may_words & list            ).present?
            ) &&
            (bad_words & list             ).blank?   &&
            (must_words - list            ).blank?
          else
            all_words   = expression.split(/\ /).select(&:present?).map(&:squish)
            (all_words.include? WILDCARD  ) || 
            (all_words & list             ).present?
          end
        end #def 
        
        def expression(expression)
          return [expression.squish].select(&:present?) if expression.to_s.match?(/\A#{Regexp.escape EXPRFLAG}/)
          return expression.split(/\ /).uniq.select(&:present?)
        end #def
        
      end #class
    end #module
  end #module
end #module
