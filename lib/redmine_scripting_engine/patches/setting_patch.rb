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
    module SettingPatch
      def self.included(base)
        base.class_eval do
          
          def self.plugin_redmine_scripting_engine=(value)
          
            # reset to factory settings
            if value["reset"].present?
              Setting.where(:name => :plugin_redmine_scripting_engine).delete_all
              #self[:plugin_redmine_scripting_engine]= nil # do not save anything
              
            else # save settings
            
              # register classes
              if value["register_classes"].present?
                register_classes = value["register_classes"].to_s.split(/;|,|\ /)
                register_classes.each do |register_class|
                  value["registered_classes"] =
                  value["registered_classes"].to_h.
                  merge(register_class.underscore => {'associations' => ['all'], 'attributes_filter' => ''})
                end
                value["register_classes"] = ""
              end
              
              # delete registered class
              if value["registered_classes"].present?
                value["registered_classes"].each do |registered_class, properties|
                  if properties['unregister'].to_i > 0
                    value["registered_classes"].except!(registered_class)
                  end
                end
              end
              
              # protect wikiscripts
              if value["wikiscripts_root"].present?
                
                # if wikiscripts_root changed, invalidate wikiscripts cache
                if self[:plugin_redmine_scripting_engine] &&
                   self[:plugin_redmine_scripting_engine]["wikiscripts_root"] !=
                   value["wikiscripts_root"]
                  RedmineScriptingEngine::Lib::RseWikiScript.invalidate_wikiscripts_key
                end
              
                # lock only on demand
                if value["lock_wikiscripts"]
                  # find projects with activated module 'redmine_scripting_engine'
                  projects    = Project.joins(:enabled_modules).
                                  where(:enabled_modules => {:name => 'redmine_scripting_engine'})
                                  
                  # iterate through these projects having a Wiki
                  projects.each do |p|
                    if p.wiki
                      # iterate through wikiscripts_root
                      p.wiki.pages.where(:title => value["wikiscripts_root"].to_s).each do |page|
                        # protect wikiscripts_root
                        page.update_attribute :protected, true
                        # protect wikiscripts_root descendants
                        WikiPage.where(:id => page.descendants.map(&:id)).update_all(:protected => true)
                      end
                    end
                  end
                end
              end
              
              # invalidate wikiscripts cache in case of change of inheritance
              if self[:plugin_redmine_scripting_engine] &&
                 self[:plugin_redmine_scripting_engine]["inherit_wikiscripts"] !=
                 value["inherit_wikiscripts"]
                RedmineScriptingEngine::Lib::RseWikiScript.invalidate_wikiscripts_key
              end
                
              # eventually, save settings
              self[:plugin_redmine_scripting_engine]= value
            end
            
          end #def
          
        end #base
      end #self
    end #module
  end #module
end #module

unless Setting.included_modules.include?(RedmineScriptingEngine::Patches::SettingPatch)
  Setting.send(:include, RedmineScriptingEngine::Patches::SettingPatch)
end


