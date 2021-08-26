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
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
    
        desc "Prints out current Environment\n" +
             "for RedmineScriptingEngine plugin.\n" +
             "Added by RedmineScriptingEngine plugin.\n" +
             "parameters: none \n"
             
        macro :rseenv do |obj, args, text|
        
          ################################################################################
          # common strategy:
          #                  1. module enabled?
          #                  2. load helpers
          #                  3. get arguments
          #                  4. filter, set/unset options
          #                  5. language supported by Redmine's CodeRay?
          #                  6. create code
          #                  7. language supported by RedmineScriptingEngine (executable?)
          #                  8. user allowed?
          #                  9. in preview, disable buttons
          #                  
          ################################################################################
          project = @project || obj.try(:project)
          
          ################################################################################
          # 1. module enabled?
          ################################################################################
          
          ################################################################################
          # 2. load helpers
          ################################################################################
          #noop
          
          ################################################################################
          # 3. get arguments
          ################################################################################
          #noop
          
          ################################################################################
          # 4. filter, set/unset options
          ################################################################################
          #noop
          installed            = !!Redmine::Plugin.registered_plugins[:redmine_scripting_engine]
          migrated             = CustomValue.columns.map(&:name).include?("script_cache")
          project              = @project || obj.try(:project)
          enabled              = project.try(:module_enabled?, :redmine_scripting_engine)
          enable_html          = Setting["plugin_redmine_scripting_engine"]["enable_html"].to_i > 0 rescue nil
          enable_mime          = Setting["plugin_redmine_scripting_engine"]["enable_mime"].to_i > 0 rescue nil
          issue_cm             = Setting["plugin_redmine_scripting_engine"]["issue_context_menu"].to_i > 0 rescue nil
          time_entry_cm        = Setting["plugin_redmine_scripting_engine"]["time_entry_context_menu"].to_i > 0 rescue nil
          issue_attachments_cm = Setting["plugin_redmine_scripting_engine"]["issue_attachment_context_menu"].to_i > 0 rescue nil 
          contact_cm           = Setting["plugin_redmine_scripting_engine"]["contact_context_menu"].to_i > 0 rescue nil 
          wikiscripts_root     = Setting["plugin_redmine_scripting_engine"]["wikiscripts_root"] rescue nil
          inherit              = Setting["plugin_redmine_scripting_engine"]["inherit_wikiscripts"].to_i > 0 rescue nil
          wikiscript_lib_paths = RSE_SUPPORTED_TYPES.map{|type| [type, RseWikiScript.library_path(project, type )] }.to_h
          
          user_permissions     =
          %i(view_scripts run_scripts run_red_scripts run_html_scripts run_mime_scripts run_tries 
             run_snippets run_fiddles run_html_fiddles run_mime_fiddles write_snippets write_fiddles
             write_html_fiddles write_mime_fiddles).map do |permission| 
              [permission, User.current.allowed_to?(permission, project, :global => project.nil?) ]
          end.to_h
          
          
          ################################################################################
          # 5. language supported?
          ################################################################################
          #noop
          
          ################################################################################
          # 6. create code html
          ################################################################################
          content_tag(:table, :class => "list") do
            content_tag(:thead) do
              content_tag(:tr) do
                content_tag(:th, "Test") + 
                content_tag(:th, "Result")
              end 
            end +
            content_tag(:tbody) do
              content_tag(:tr) do
                content_tag(:td, "Installed?") + 
                content_tag(:td, content_tag(:span, "", :class =>  installed ? 'icon icon-ok' : 'icon icon-not-ok'))
              end + 
              content_tag(:tr) do
                content_tag(:td, "Migrated?") + 
                content_tag(:td, content_tag(:span, "", :class =>  migrated ? 'icon icon-ok' : 'icon icon-not-ok'))
              end + 
              content_tag(:tr) do
                content_tag(:td, "Project") + 
                content_tag(:td, project ? project.name : "- none -")
              end + 
              content_tag(:tr) do
                content_tag(:td, "Plugin enabled?") + 
                content_tag(:td, content_tag(:span, "", :class =>  enabled ? 'icon icon-ok' : 'icon icon-not-ok'))
              end + 
              content_tag(:tr) do
                content_tag(:td, "HTML enabled?") + 
                content_tag(:td, content_tag(:span, "", :class =>  enable_html ? 'icon icon-ok' : 'icon icon-not-ok'))
              end + 
              content_tag(:tr) do
                content_tag(:td, "MIME enabled?") + 
                content_tag(:td, content_tag(:span, "", :class =>  enable_mime ? 'icon icon-ok' : 'icon icon-not-ok'))
              end + 
              content_tag(:tr) do
                content_tag(:td, "Issues Context Menu?") + 
                content_tag(:td, content_tag(:span, "", :class =>  issue_cm ? 'icon icon-ok' : 'icon icon-not-ok'))
              end + 
              content_tag(:tr) do
                content_tag(:td, "Time Entries Context Menu?") + 
                content_tag(:td, content_tag(:span, "", :class =>  time_entry_cm ? 'icon icon-ok' : 'icon icon-not-ok'))
              end + 
              content_tag(:tr) do
                content_tag(:td, "Issue Attachments Context Menu?") + 
                content_tag(:td, content_tag(:span, "", :class =>  issue_attachments_cm ? 'icon icon-ok' : 'icon icon-not-ok'))
              end + 
              content_tag(:tr) do
                content_tag(:td, "Contacts Context Menu?") + 
                content_tag(:td, content_tag(:span, "", :class =>  contact_cm ? 'icon icon-ok' : 'icon icon-not-ok'))
              end + 
              content_tag(:tr) do
                content_tag(:td, "WikiScripts Root") + 
                content_tag(:td, wikiscripts_root.to_s)
              end + 
              content_tag(:tr) do
                content_tag(:td, "Inherit WikiScripts?") + 
                content_tag(:td, content_tag(:span, "", :class =>  inherit ? 'icon icon-ok' : 'icon icon-not-ok'))
              end +
              content_tag(:tr) do
                content_tag(:td, "WikiScripts Libraries Path") + 
                content_tag(:td) do
                  wikiscript_lib_paths.map do |type, tree|
                    content_tag(:table, :class => "list") do
                      content_tag(:thead) do
                        content_tag(:tr) do
                          content_tag(:th, "Type", :style => "width:20%;") + 
                          content_tag(:th, "Branch / Locked", :style => "width:80%;")
                        end #tr
                      end +
                      content_tag(:tbody) do
                        content_tag(:tr) do
                          content_tag(:td, type) + 
                          content_tag(:td) do
                            content_tag(:table, :class => "list") do
                              content_tag(:thead) do
                                tree.map do |branch, protected|
                                  content_tag(:tr) do
                                     content_tag(:td, branch, :style => "width:80%;") +
                                     content_tag(:td, content_tag(:span, "", :class =>  protected ? 'icon icon-ok' : 'icon icon-not-ok'), :style => "width:20%;")
                                  end
                                end.join.html_safe
                              end
                            end
                          end #td
                        end #tr
                      end #tbody
                    end #table
                  end.join.html_safe #map
                end #td
              end +
              content_tag(:tr) do
                content_tag(:td, "Permissions") + 
                content_tag(:td) do
                  content_tag(:table, :class => "list") do
                    content_tag(:thead) do
                      content_tag(:tr) do
                        content_tag(:th, "Permission") + 
                        content_tag(:th, "Test")
                      end #tr
                    end +
                    content_tag(:tbody) do
                      user_permissions.map do |p|
                        content_tag(:tr) do
                          content_tag(:td, p[0].to_s.humanize, :style => "width:84%;") + 
                          content_tag(:td, content_tag(:span, "", :class =>  p[1] ? 'icon icon-ok' : 'icon icon-not-ok'), :style => "width:16%;")
                        end #tr
                      end.join.html_safe #map
                    end
                  end
                end
              end 
            end
          end
        end #macro
        
    end #register
    
  end #module
end #module
