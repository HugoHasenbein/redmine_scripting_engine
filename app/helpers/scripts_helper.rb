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

module ScriptsHelper
  
  def _run_project_script_path(project, id, *args)
    project ? run_project_script_path(project.identifier, id, *args) : run_script_path(id, *args)
  end #def
  
  def _fiddle_project_script_path(project, id, *args)
    project ? fiddle_project_script_path(project.identifier, id, *args) : fiddle_script_path(id, *args)
  end #def
  
  def embed_as_html(obj)
    content_tag(:div, :class => "pre") do
      obj.to_s.encode("UTF-8", replace:'', invalid: :replace, undef: :replace).html_safe
    end
  end #def
  
  def embed_as_text(obj)
    content_tag(:pre) do
      obj.to_s.encode("UTF-8", replace:'', invalid: :replace, undef: :replace) # will do CGI.escapeHTML
    end
  end #def
  
  def script_out_filename(script, fsize)
    CGI.escapeHTML(filename_for_content_disposition( [script.title, script.ext].join )) + ": #{fsize}"
  end #def
  
  def wikiscript_root(project)
    wikiscripts_root = Setting["plugin_redmine_scripting_engine"]["wikiscripts_root"]
    Wiki.find_page(wikiscripts_root, :project => project)
  end #def
  
  def wikiscript_sort_link(column, caption, default_order)
    css, order = nil, default_order
    
    if column.to_s == @sort_criteria.first_key
      if @sort_criteria.first_asc?
        css = 'sort asc icon icon-sorted-asc'
        order = 'desc'
      else
        css = 'sort desc icon icon-sorted-desc'
        order = 'asc'
      end
    end
    caption = column.to_s.humanize unless caption
    
    sort_options = { :sort => @sort_criteria.add(column.to_s, order).to_param }
    link_to(caption, {:params => request.query_parameters.merge(sort_options)}, :class => css)
  end
  
  def wikiscript_sort_header_tag(column, options = {})
    caption = options.delete(:caption) || column.to_s.humanize
    default_order = options.delete(:default_order) || 'asc'
    options[:title] = l(:label_sort_by, "\"#{caption}\"") unless options[:title]
    content_tag('th', wikiscript_sort_link(column, caption, default_order), options)
  end
  
end #module

