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
    
        desc "inserts an input tag of type :check-box, :color, :date, :datetime-local, :email, \n" +
             ":month, :number, password, :radio, :range, :text, :time, :url, :week, :search \n" +
             "with attributes :name, :value, :id, :size, :min, :max, :maxlength \n" +
             ":step, :placeholder, :autofocus, :height, :width :multiple. \n" +
             "Attribute :name must begin with [a-zA-Z0-9-]" +
             "Example:\n" +
             "{{input(type=text,size=10, name=foo)}}"
             
        macro :input do |obj, args|
          
          ################################################################################
          # get arguments
          ################################################################################
          # excluded :class, :on… , :style
          args, options = extract_macro_options(args, :type, :name, :value, :id, :size, 
            :min, :max, :maxlength, :step, :placeholder, :autofocus, :height, :width,
            :multiple, :pattern, :required, :autocomplete, :label, :checked, :disabled)
            
          ################################################################################
          # type: excluded are :button, :reset, :submit, :file, :image, :tel
          ################################################################################
          type   = options.delete(:type).presence
          type   = (%w(check-box color date datetime-local email month number password radio range
                       text time url week search ) & [type])[0]
          type ||= "text" # default
          
          type = case type
          when 'radio'
            third = !!options.delete(:checked)
            "radio_button"
          when 'check-box'
            third = !!options.delete(:checked)
            "check_box"
          else
            third = nil
            "#{type.underscore}_field"
          end
          
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
          # get value
          ################################################################################
          value = options.delete(:value).to_s
          
          ################################################################################
          # should label be written?
          ################################################################################
          label = options.delete(:label).presence
          
          ################################################################################
          # standard arguments
          ################################################################################
          disabled = true if controller.class == PreviewsController || params[:action] == "preview"
          options.merge!(:disabled => true) if disabled
          
          ################################################################################
          # write input
          ################################################################################
          send_args = ["#{type}_tag".to_sym, name, value, third, options].compact
          (label ? label_tag(name, label) : "".html_safe) + send( *send_args )
          
        end #macro
        
    end #register
    
  end #module
end #module
