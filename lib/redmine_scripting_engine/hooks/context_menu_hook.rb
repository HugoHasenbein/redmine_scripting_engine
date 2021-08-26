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
  module Hooks
    class ContextMenuHook < Redmine::Hook::ViewListener
    
      def view_issues_context_menu_end(context={ })
        context[:controller].send(:render_to_string, {
          :partial => 'hooks/redmine_scripting_engine/context_menu',
          :locals => context.merge(:objects => context[:issues], :class_name => "Issue")
        }) if context[:issues].map(&:project).uniq.all?{|project| project.module_enabled?(:redmine_scripting_engine)} &&
           Setting["plugin_redmine_scripting_engine"]["issue_context_menu"]
      end #def
      
      def view_time_entries_context_menu_end(context={ })
        context[:controller].send(:render_to_string, {
          :partial => 'hooks/redmine_scripting_engine/context_menu',
          :locals => context.merge(:objects => context[:time_entries], :class_name => "TimeEntry")
        }) if context[:time_entries].map(&:project).uniq.all?{|project| project.module_enabled?(:redmine_scripting_engine)} &&
           Setting["plugin_redmine_scripting_engine"]["time_entry_context_menu"]
      end #def
      
      def view_issue_attachments_context_menu_end(context={ })
        context[:controller].send(:render_to_string, {
          :partial => 'hooks/redmine_scripting_engine/context_menu',
          :locals => context.merge(:objects => context[:issue_attachments], :class_name => "IssueAttachment")
        }) if context[:issue_attachments].map(&:project).uniq.all?{|project| project.module_enabled?(:redmine_scripting_engine)} &&
           Setting["plugin_redmine_scripting_engine"]["issue_attachment_context_menu"] &&
           Redmine::Plugin.installed?("redmine_issue_attachments")
      end #def
      
      def view_contacts_context_menu_end(context={ })
        context[:controller].send(:render_to_string, {
          :partial => 'hooks/redmine_scripting_engine/context_menu',
          :locals => context.merge(:objects => context[:contacts], :class_name => "Contact")
        }) if context[:contacts].map(&:project).uniq.all?{|project| project.module_enabled?(:redmine_scripting_engine)} &&
           Setting["plugin_redmine_scripting_engine"]["contact_context_menu"] &&
           Redmine::Plugin.installed?("redmine_contacts")
      end #def
      
    end
  end
end