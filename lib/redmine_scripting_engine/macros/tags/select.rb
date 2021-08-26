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
    
        desc "inserts a select tag with :name, :id, :size, :value, :autofocus, :prompt, :include_blank, :required, :multiple, :label \n" +
             "all other attributes are ignored \n" +
             "{{select(name='Select!') \n" +
             "option \n" +
             "option \n" +
             "option \n" +
             "}}"
             
        macro :select do |obj, args, text|
        
          ################################################################################
          # get arguments
          ################################################################################
          # excluded :class, :on… , :style
          args, options = extract_macro_options(args, :name, :id, :size, :value, :autofocus, 
          :prompt, :include_blank, :required, :multiple, :label)
          
          ################################################################################
          # sanitize name
          ################################################################################
          name = options.delete(:name).presence
          name ||= "text" # default
          # variable must parenthesized[], 
          # must use '' for replacement pattern
          if name.match?(/\A([a-zA-Z0-9-_]*)/)
            name.gsub!(/\A([a-zA-Z0-9-_]*)/, '[\1]') 
          else
            name = "modal[#{name}]"
          end
          name = "modal#{name}"
          
          ################################################################################
          # selected value
          ################################################################################
          selected = options.delete(:value)
          
          ################################################################################
          # select values from text
          ################################################################################
          values = text.to_s.split(/[\n\r]+/).select(&:present?) #TODO: parse options
          
          ################################################################################
          # should label be written?
          ################################################################################
          label = options.delete(:label).presence
          
          ################################################################################
          # standard arguments
          ################################################################################
          disabled = true if controller.class == PreviewsController || params[:action] == "preview"
          
          ################################################################################
          # write button
          ################################################################################
          (label ? label_tag(name, label) : "".html_safe) + 
          select_tag(name, options_for_select([values,values].transpose, selected), options)
          
        end #macro
        
    end #register
    
  end #module
end #module
