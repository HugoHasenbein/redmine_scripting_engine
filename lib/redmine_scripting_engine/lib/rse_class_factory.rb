# encoding: utf-8
#
# Redmine plugin for administration of IP
#
# Copyright © 2018 Stephan Wenzel <stephan.wenzel@drwpatent.de>
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
    module RseClassFactory
      class << self
        
        # ------------------------------------------------------------------------------ #
        #
        # create_class
        #
        # usage: ClassFactory.create_class "Car", :superclass => klass, :fields => ["make", "model", "year"], :constants => {"WHEELS" => 4}
        #        
        #          new_class = Car.new
        #          new_class.make = "Nissan"
        #          puts new_class.make # => "Nissan"
        #          new_class.model = "Maxima"
        #          puts new_class.model # => "Maxima"
        #          new_class.year = "2001"
        #          puts new_class.year # => "2001"
        #          puts Car::WHEELS # => 4
        #          
        #          
        def create_class(klass, options={})
          c = Class.new(*[options[:superclass]].compact) do
          
            # define constants
            constants = options[:constants].to_h
            constants.each do |k, v|
              const_set k, v
            end
            
            # define fields
            fields = options[:fields].to_a
            fields.each do |field|
              define_method field.intern do
                instance_variable_get("@#{field}")
              end
              define_method "#{field}=".intern do |arg|
                instance_variable_set("@#{field}", arg)
              end
            end
            
          end
          Object.const_set klass, c
        end #def
        
        # ------------------------------------------------------------------------------ #
        #
        # get_ancestor_class_names
        # 
        # usage: ancestor_classes("MyClass") --- called with a string
        #        ancestor_classes( MyClass ) --- called with a class
        #        ancestor_classes( object  ) --- called with an arbitrary object 
        #        
        #        ancestor_classes( "All"   ) --- exception: returns "All" (like a wildcard)
        #        
        #        
        def ancestor_classes(obj, names: true)
        
          case obj
          
          when String
            return [obj] if obj == RseWikiScript::WILDCARD
            klass ||= obj.constantize rescue nil
            return [] unless klass
            
          when Class
            klass   = obj
            
          when Object
            klass ||= obj.class
            
          end
          
          # remove modules from ancestor list
          klasses = klass.ancestors.select{|k| k.is_a?(Class)}
          
          # remove gem superclasses
          klasses = klasses.take_while{|k| defined?(klass.base_class) ?
                                           k != klass.base_class.superclass :
                                           k != klass.superclass
                                       }
                                       
          # get names, if chosen. not all classes respond to :name
          klasses.map!{|k| k.name rescue k.to_s rescue nil}.compact if names
          
          klasses
        end #def
        
        # ------------------------------------------------------------------------------ #
        #
        # descendant_classes
        #
        #
        #
        def descendant_classes(obj, names: true)
        
          case obj
          
          when String
            return [obj] if obj == RseWikiScript::WILDCARD
            klass ||= obj.constantize rescue nil
            return [] unless klass
            
          when Class
            klass = obj
            
          when Object
            klass = obj.class
            
          end
          # remove modules from descendants list
          klasses =  [klass] + klass.descendants.select{|k| k.is_a?(Class)}
          
          # get names, if chosen. not all classes respond to :name
          klasses.map!{|k| k.name rescue k.to_s rescue nil}.compact if names
          
          klasses
        end #def
        
        
      end #class
    end #module
  end #module
end #module

