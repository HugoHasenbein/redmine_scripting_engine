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
    module FieldFormatPatch
      def self.included(base)
        base.class_eval do
        
          field_attributes :script, :script_type
          
        end #base
      end #self
    end #module
  end #module
end #module

unless Redmine::FieldFormat::Base.included_modules.include?(RedmineScriptingEngine::Patches::FieldFormatPatch)
  Redmine::FieldFormat::Base.send(:include, RedmineScriptingEngine::Patches::FieldFormatPatch)
end

module RedmineScriptingEngine
  module Patches 
    module FieldFormatExtension
    
      def formatted_custom_value(view, custom_value, html=false)
      
        case custom_value
        when CustomValue
          cv = custom_value
        when CustomFieldValue
          cv = custom_value.custom_value
        end
        
        if redmine_scripting_engine_activated(custom_value) &&
           custom_value.custom_field.script_type.present? && 
           (cv.is_a?(Array) ? cv.first.script_cache.blank? : cv.script_cache.blank?)
           
          run_wikiscript(view, custom_value, html)
          
        elsif custom_value.script_cache.present?
          unless redmine_scripting_engine_activated(custom_value)
            # here we catch orphaned caches, which exist after deactivation of plugin
            formatted_value(view, custom_value.custom_field, custom_value.value, custom_value.customized, html)
          else
            case custom_value.script_cache
            when Array
              custom_value.script_cache.first
            else
              custom_value.script_cache
            end
          end
          
        else
          formatted_value(view, custom_value.custom_field, custom_value.value, custom_value.customized, html)
        end
        
      end #def
      
      def run_wikiscript(view, custom_value, html)
        view.instance_variable_set('@eparams', view.params.to_unsafe_hash)
        args = view.script_args(custom_value.customized).merge(
          :custom_value => {
            :custom_field => RedmineScriptingEngine::Digger.new(custom_value.custom_field).dig,
            :value        => custom_value.value,
            :html         => html
          }
        )
        script = RedmineScript.from_text( 
          custom_value.custom_field.script, 
          custom_value.custom_field.script_type,
          :project =>  view.instance_variable_get('@project')
        )
        script.arguments = args
        result = script.run(true) # run with libraries and dumped data
        
        if result.is_a?(String) 
        result = result.encode("UTF-8", :force => true, :undef => :replace, :replace => "")
        end
        
        case custom_value
        when CustomValue
          custom_value.update_column(:script_cache, result)
        when CustomFieldValue
          case custom_value.custom_value
          when CustomValue
            custom_value.custom_value.update_column(:script_cache, result)
          when Array
            CustomValue.where(:id => custom_value.custom_value.map(&:id)).update_all(:script_cache => result)
          end
        end
        
        result
      end #def
      
      def redmine_scripting_engine_activated(custom_value)
        custom_value.customized.respond_to?(:project) ? custom_value.customized.try(:project).try(:module_enabled?, :redmine_scripting_engine) : true
      end #def
      
      def after_save_custom_value(custom_field, custom_value)
        custom_value.update_column(:script_cache, nil)
        super
      end
    
    end #module
  end #module
end #module

module Redmine
  module FieldFormat
    class Base
      prepend RedmineScriptingEngine::Patches::FieldFormatExtension
    end #class
  end #module
end #module

