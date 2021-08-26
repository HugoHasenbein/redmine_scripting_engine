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
    module SettingsHelperPatch
      def self.included(base)
        base.class_eval do
        
          unloadable 
          
          def object_associations_chooser(klass, local_assigns)
            render :partial => "plugin_settings/redmine_scripting_engine/object_associations_chooser", :locals => local_assigns.merge(:klass => klass)
          end #def
          
          # returns object associations select option
          def select_associations(name, associations, selected, options={})
            option_tags = ''.html_safe
            multiple = false
            if selected
              if selected.size == associations.size
                selected = 'all'
              else
                # selected = selected.map(&:name) # settings is aleady a string
                if selected.size > 1
                  multiple = true
                end
              end
            else
              selected = associations.first.try(:name)
            end
            all_tag_options = {:value => 'all', :selected => (selected == 'all')}
            unless multiple
              option_tags << content_tag('option', l(:label_all), all_tag_options)
            end
            option_tags << options_from_collection_for_select(associations, "name", "name_with_visibility_flag", selected)
            select_tag name, option_tags, {:multiple => multiple, :size => multiple ? 10 : nil}.merge(options).compact
          end #def
          
          def scriptable_classes
            Rails.application.eager_load!
            # unselect pseudo classes as HABTM_<class name> and only main classes, not modulized classes, i.e. Module::Class
            ActiveRecord::Base.descendants.select{|klass| klass.name.safe_constantize && klass.name !~ /:/ }
          end #def
          
          def scriptable_classes_for_select
            klasses = scriptable_classes
            options_for_select(
              klasses.map{|klass| [l("label_#{klass.name.underscore}_plural".to_sym, :default => klass.name.underscore.humanize) + " (#{klass.name})", klass.name.underscore]}.sort
            )
          end #def
          
        end #base
      end #self
    end #module
  end #module
end #module

unless SettingsHelper.included_modules.include?(RedmineScriptingEngine::Patches::SettingsHelperPatch)
  SettingsHelper.send(:include, RedmineScriptingEngine::Patches::SettingsHelperPatch)
end


