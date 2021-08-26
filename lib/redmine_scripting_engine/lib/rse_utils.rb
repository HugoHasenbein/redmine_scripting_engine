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
  module Lib
    module RseUtils
    
      ################################################################################
      # serializes object to OpenStruct
      ################################################################################
      def serialize(object, **options)
        if object.is_a?(Hash)
           OpenStruct.new(object.map{ |key, val| [ key, serialize(val, options) ] }.to_h)
        elsif object.is_a?(Array)
           object.map{ |obj| serialize(obj, options) }
        else # assumed to be a primitive value
          if options[:parse]
            JSON.parse(object, object_class:OpenStruct) rescue object 
          else
            object
          end
        end
      end #def
      
      ################################################################################
      # deserializes object from OpenStruct
      ################################################################################
      def deserialize(object)
        if object.is_a?(OpenStruct)
          return deserialize( object.to_h )
        elsif object.is_a?(Hash)
          return object.map{|key, obj| [key, deserialize(obj)]}.to_h
        elsif object.is_a?(Array)
          return object.map{|obj| deserialize(obj)}
        else # assumed to be a primitive value
          return object
        end
      end #def
      
      ################################################################################
      # error_response with rails exception
      ################################################################################
      def error_response(exception, output="")
        serialize(
          output: output,
          error:  {message:   exception.message, 
                   backtrace: exception.backtrace },
          status: exception.class.name
        )
      end #def
      
    end #module
  end #module
end #module
