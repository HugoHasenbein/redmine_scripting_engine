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
  module Patches 
    module ApplicationHelperPatch
      def self.included(base)
        base.class_eval do
        
          unloadable 
          
          # returns boolean for user permission
          def user_allowed_to_run_scripts(objects)
            objects.map(&:project).uniq.all?{|project| User.current.allowed_to?(:run_scripts, project) }
          end #def
          
          # returns boolean for user permission
          def user_allowed_to_run_red_scripts(objects)
            objects.map(&:project).uniq.all?{|project| User.current.allowed_to?(:run_red_scripts, project)}
          end #def
          
          # returns wikiscripts for objects
          def wikiscripts( objects, options={} )
            RedmineScriptingEngine::Lib::RseWikiScript.find_for(objects, options)
          end #def
          
          # returns wikiscripts for objects
          def class_wikiscripts( klass, options={} )
            RedmineScriptingEngine::Lib::RseWikiScript.class_wikiscripts( klass, options )
          end #def
          
          # proviedes parameters passed to wikiscript
          def script_args(obj=nil, objects=[])
            {:objects       => objects.map{|obj| RedmineScriptingEngine::Digger.new(obj).dig }, # arbitrary objects
             :object        => RedmineScriptingEngine::Digger.new(obj).dig,                     # script embedding object
             :project       => RedmineScriptingEngine::Digger.new(obj).dig_project.presence || @project,
             :user          => RedmineScriptingEngine::Digger.new(User.current).dig,            # current user
             :api_key       => User.current.api_key,
             :params        => params.to_unsafe_hash,                                           # params of calling url
             :eparams       => @eparams,                                                        # params of embedding object
             :site_user     => Setting["plugin_redmine_scripting_engine"]["site_user"],
             :site_password => Setting["plugin_redmine_scripting_engine"]["site_password"],
             :urls          => {"back" => request.url,
                                "Home" => home_url},
             :attachments   => RedmineScriptingEngine::Digger.new(obj).dig_attachments.map{|att| att[1]}
            }
          end #def
          
          # returns attachments ob object
          def object_attachments(obj=nil)
            RedmineScriptingEngine::Digger.new(obj).dig_attachments
          end #def
          
        end #base
      end #self
    end #module
  end #module
end #module

unless ApplicationHelper.included_modules.include?(RedmineScriptingEngine::Patches::ApplicationHelperPatch)
  ApplicationHelper.send(:include, RedmineScriptingEngine::Patches::ApplicationHelperPatch)
end


