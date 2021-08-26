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
    module CustomizablePatch
      def self.included(base)
        base.module_eval do
        
          def custom_field_values
            @custom_field_values ||= available_custom_fields.collect do |field|
              x = CustomFieldValue.new
              x.custom_field = field
              x.customized = self
              if field.multiple?
                values = custom_values.select { |v| v.custom_field == field }
                if values.empty?
                  values << custom_values.build(:customized => self, :custom_field => field)
                end
                x.instance_variable_set("@value", values.map(&:value))
                x.custom_value = values # hold all custom values
                x.script_cache = values.map(&:script_cache)
              else
                cv = custom_values.detect { |v| v.custom_field == field }
                cv ||= custom_values.build(:customized => self, :custom_field => field)
                x.instance_variable_set("@value", cv.value)
                x.custom_value = cv # hold just the custom_value
                x.script_cache = cv.script_cache
              end
              x.value_was = x.value.dup if x.value
              x
            end
          end #def
          
        end #base
      end #self
    end #module
  end #module
end #module

unless Redmine::Acts::Customizable::InstanceMethods.included_modules.include?(RedmineScriptingEngine::Patches::CustomizablePatch)
  Redmine::Acts::Customizable::InstanceMethods.send(:include, RedmineScriptingEngine::Patches::CustomizablePatch)
end


