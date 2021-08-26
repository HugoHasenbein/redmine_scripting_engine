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
    
        desc "inserts a link to the current project or \n" +
             "inserts a link to the named project \n" +
             "Example:\n" +
             "{{project}} will insert link to project of current object \n" +
             "{{project(my-project)}} will insert link to project with identifier 'my-project' \n"
             
        macro :project do |obj, args, text|
        
          # try read project from args
          if args[0]
            project = Project.find(args[0]) rescue nil
          end
          
          # else try read project from object or @project
          project ||= obj.try(:project) || @project
          
          # return unless project present
          return nil unless project
          
          # eventually create link
          content_tag(:a, project.name, :href => project_path(project.identifier))
        end #macro
        
    end #register
    
  end #module
end #module
