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
  class Digger
    
    ######################################################################################
    #
    # Digger
    #
    ######################################################################################
    
    ######################################################################################
    # delegate
    ######################################################################################
    delegate :url_helpers, :to => "Rails.application.routes"
  
    ######################################################################################
    # initialize
    ######################################################################################
    def initialize(object)
      @object     = (object.is_a?(ActiveSupport::HashWithIndifferentAccess) || object.is_a?(Hash)) ? instantiate_object(object) : object
      @params     = (object.is_a?(ActiveSupport::HashWithIndifferentAccess) || object.is_a?(Hash)) ? object[:params].to_h : {}
      @class_name = @object.class.name
      @model      = @class_name.underscore
      @models     = @model.pluralize
    end #def
    
    ######################################################################################
    # digs object's database associations and attributes
    ######################################################################################
    def dig
    
      attributes = {}
      
      # add objects' class_name
      attributes.merge! :class_name => (@object.is_a?(Class) ? @object.name : @object.class.name) if @object
      
      # add objects' custom params
      attributes.merge! :params => @params if @object
      
      # if only a class is given then return, else find associations
      return attributes if @object.is_a?(Class)
      
      if @object && (@object.try(:visible?) || @object.try(:visible?).nil?)
      
        # add objects' to_s representation
        attributes.merge! :to_string => @object.to_s 
        
        # add object's own attributes
        attributes.merge! filter_forbidden_attributes( @object )
        
        # add object's special attributes
        attributes.merge!( add_special_attributes )
        
        # add objects main urls
        attributes.merge! :object_url  => object_url( @object) if object_url( @object)
        attributes.merge! :objects_url => objects_url(@object) if objects_url(@object)
        
        # add all object's active_record associations ( one level )
        @object.class.reflect_on_all_associations.each do |assoc|
          
          next unless allowed_asscociation( assoc.name )
          
          association = nil
          
          # fetch associations based on user's permission
          if assoc.collection?
            if assoc.protected_by_visibility?
              association = (@object.send assoc.name).visible.to_a rescue [] # catch query's class method 'visible'
            else
              association = (@object.send assoc.name).to_a
            end
          else
            if assoc.protected_by_visibility?
              association = @object.send assoc.name if (@object.send assoc.name).try(:visible?)
            else
              association = (@object.send assoc.name)
            end
          end
          
          # filter out globally forbidden attributes
          if association.is_a?(Array)
            attr = association.map!{|ass| filter_forbidden_attributes( ass ).merge( add_special_attributes(ass) ) }
          else
            attr = filter_forbidden_attributes( association ).merge( add_special_attributes(association) )
          end
          
          attributes.merge!( assoc.name => attr.presence )
          
        end if @object.class.respond_to?(:reflect_on_all_associations)
      end
      
      apply(attributes) do |attribute|
        attribute.to_s.encode("UTF-8", replace:"")
      end
      
    end #def
    
    ######################################################################################
    # digs object's project
    ######################################################################################
    def dig_project
      initialize(@object.try(:project))
      dig
    end #def
    
    ######################################################################################
    # digs object's attachments
    ######################################################################################
    def dig_attachments
      if @object.respond_to?(:attachments)
        @object.attachments.map do |att|
          [att.diskfile, att.filename]
        end
      end.to_h
    end #def
    
    private
    
    ######################################################################################
    # instantiates an object from params, honors visibility
    ######################################################################################
    def instantiate_object(attributes)
    
      # args must be a hash
      return nil unless attributes.is_a?(Hash) || attributes.is_a?(ActiveSupport::HashWithIndifferentAccess)
      
      # try to instanciate klass
      klass = attributes[:class].safe_constantize if attributes[:class]
      return nil unless klass
      
      if attributes[:id]
        # try to find klass object, else return class itself
        return klass unless klass.respond_to?(:find)
        object = klass.find(attributes[:id]) 
        
        # return object only if it is visible
        return nil unless object.respond_to?(:visible?)
        return nil unless object.visible?
        return object
        
      else
        return klass
        
      end
      
    rescue ActiveRecord::RecordNotFound
      nil
    end #def
    
    ######################################################################################
    # deep_try, like has.dig(*keys) for methods
    ######################################################################################
    def deep_try(obj, *fields)
      fields.inject(obj) {|obj,field| obj.try(field.to_s.to_sym)}
    end #def
    
    ######################################################################################
    # puts object into an array unless Array already
    ######################################################################################
    def arrify( object )
      object.is_a?(Array) ? object : [object]
    end #def
    
    ######################################################################################
    # tries to get object (singular) url
    ######################################################################################
    def object_url(object)
      url_helpers.try(        "#{@model}_url".to_sym, :protocol => Setting.protocol, :host => Setting.host_name, :id => object.try(:id) ) || 
      url_helpers.try("project_#{@model}_url".to_sym, :protocol => Setting.protocol, :host => Setting.host_name, :id => object.try(:id), :project_id => object.try(:project).try(:id))
    end #def
    
    ######################################################################################
    # tries to get objects (plural) url
    ######################################################################################
    def objects_url(object)
      # catch objects having a non-pluralizable name, i.e. 'news'
      models = @models == @model ? "#{@models}_index" : @models
      url_helpers.try(         "#{models}_url".to_sym, :protocol => Setting.protocol, :host => Setting.host_name) || 
      url_helpers.try( "project_#{models}_url".to_sym, :protocol => Setting.protocol, :host => Setting.host_name, :project_id => object.try(:project).try(:id)) rescue nil
    end #def
    
    ######################################################################################
    # get allowed associations from configuration for an object
    ######################################################################################
    def allowed_asscociation( assoc_name )
      return true if Setting["plugin_redmine_scripting_engine"].dig("registered_classes","#{@model}","associations").to_a.include?("all")
      return true if Setting["plugin_redmine_scripting_engine"].dig("registered_classes","#{@model}","associations").to_a.include?(assoc_name.to_s)
      return false
    end #def
    
    ######################################################################################
    # get global forbidden attributes from configuration
    ######################################################################################
    def global_forbidden_attributes
      @global_filter ||= Setting["plugin_redmine_scripting_engine"]["forbidden_attributes_filter"].to_s.split(/;|,|\ /)
    end #def
    
    ######################################################################################
    # get forbidden attributes from configuration for an object
    ######################################################################################
    def object_forbidden_attributes
      @filter        ||= Setting["plugin_redmine_scripting_engine"]["#{@model}_attributes_filter"].to_s.split(/;|,|\ /)
    end #def
    
    ######################################################################################
    # filters object's forbidden attributes
    ######################################################################################
    def filter_forbidden_attributes( object )
      attributes = object.try(:attributes).to_h.select{|key, val| !global_forbidden_attributes.include?(key.to_s) }
      if object_forbidden_attributes.present?
        attributes.select!{|key, val| !object_forbidden_attributes.include?(key.to_s) }
      end #def
      attributes
    end #def
    
    ######################################################################################
    # for some objects add special attributes
    ######################################################################################
    def add_special_attributes(obj=@object)
      case obj
      when Journal # can add special values, #textilizable won't work as this is not called from a view
      end.to_h #case
    end #def
    
    ######################################################################################
    # applies block to nested scalars of Hash or Array
    ######################################################################################
    def apply( obj, &block )
      case obj
      when Hash
        obj.map{|key, value| [key, apply( value, &block )]}.to_h
      when Array
        obj.map{|el| apply( el, &block ) }
      else
        yield obj
      end
    end #def
    
  end #module
end #module