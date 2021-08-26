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
    module JournalPatch
      def self.included(base)
        base.class_eval do
        
          def visible?
            journalized_permission = journalized.try(:visible?)
            if private_notes?
              private_permission = User.current.allowed_to?(:view_private_notes, project) || user == User.current
            end
            (journalized_permission.nil? || journalized_permission) && (private_permission.nil? || private_permission)
          end #def
          
        end #base
      end #self
    end #module
  end #module
end #module

unless Journal.included_modules.include?(RedmineScriptingEngine::Patches::JournalPatch)
  Journal.send(:include, RedmineScriptingEngine::Patches::JournalPatch)
end


