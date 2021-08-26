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
    
        desc "inserts the text content in a link to a wikipage \n" +
             "Example:\n" +
             "{{wiki(Foo) \n" +
             "!image.png!" +
             "}}"
             
        macro :wiki do |obj, args, text|
          
          return nil unless project = obj.try(:project)
          title = args[0]
          page  = Wiki.find_page( title, :project => project )
          path  = project_wiki_page_path(project.identifier, page ? page.title : title)
          css   = "wiki-page"
          css  << " new" unless page
          
          content_tag(:a, :href => path, :class => css) do
            textilizable(text, :object => obj, :headings => false, :inline_attachments => Redmine::WikiFormatting::Macros.inline_attachments)
          end
        end #macro
        
    end #register
    
  end #module
end #module
