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

require 'rack/mime'

class ScriptsController < ApplicationController

  ########################################################################################
  #
  # includes
  #
  ########################################################################################
  include ActionController::Live
  include RedmineScriptingEngine::Lib
  helper :sort
  include SortHelper
  helper :scripts        # after sort, because it overrides sort
  include ScriptsHelper
  helper :application
  include ApplicationHelper
  include ERB::Util # needed for html_escape in textilizable
  include RedmineScriptingEngine::MacrosHelper # needed for validating script signatures
  
  ########################################################################################
  #
  # delegations
  #
  ########################################################################################
  delegate :content_tag, :to => "ApplicationController.helpers"
  delegate :url_helpers, :to => "Rails.application.routes"
  
  ########################################################################################
  #
  # rescuers
  #
  ########################################################################################
  rescue_from Unauthorized, :with => :deny_access
  
  ########################################################################################
  #
  # callbacks
  #
  ########################################################################################
  before_action :find_optional_project       # does authorization on project or global
  before_action :find_script,                :only => [:run]
  before_action :build_script,               :only => [:fiddle, :snippet]
  before_action :find_objects,               :only => [:run, :fiddle]
  
  accept_api_auth :index, :run
  
  ########################################################################################
  #
  # controller functions
  #
  ########################################################################################
  
  ########################################################################################
  # index: show current WikiScripts for project
  ########################################################################################
  def index
    attr = %w(id type title klass status ext red modal? author_id)
    
    sort_init 'id', 'desc'
    sort_update attr
    
    @wikiscript_root = wikiscript_root(@project)
    
    @scripts = RedmineScriptingEngine::Lib::RseWikiScript.project_wikiscripts( @project )
    ssc = script_sort_clause.select{|sort| attr.include? sort.first }
    @scripts = @scripts.sort do |a,b| 
      ssc.map{|key,val| val == 'asc' ? a.send(key.to_s).to_s : b.send(key.to_s).to_s } <=> 
      ssc.map{|key,val| val == 'asc' ? b.send(key.to_s).to_s : a.send(key.to_s).to_s }
    end
    respond_to do |format|
      format.html
      format.api
    end
  end #def
  
  ########################################################################################
  # run: run script with real data from redmine, for privileged users only
  ########################################################################################
  def run
  
    determine_model
    common_params
    
    @each         = script_parameter.include?("each")
    @sync         = script_parameter.include?("sync")
    @back         = params[:back]
    
    #
    # params[:each]: as html call: call script one-by-one 
    #
    # params[:sync]  call synchronously in :each mode
    #
    # JS call:       inline
    #
    
    if @each
      respond_to do |format|
        format.js   { 
          render "process"
        }
        format.html { 
          render "process"
        }
        format.api {
          render "process"
        }
      end
      
    else
      parameterize_script
      
      case @script.mime
      
      ##
      # 
      # if text/html, then display result inline or return back, with just a message
      #
      when "text/html"
      
        if @script.html_safe? && User.current.allowed_to?(:run_html_scripts, nil, :global => true )
          html = embed_as_html(@script.run) 
        else
          html = embed_as_text(@script.run) 
        end
      
        respond_to do |format|
          format.js   {
            render "act", :locals => {:html => html}
          }
          format.html { 
            flash[:notice] = success_message
            redirect_to :back
          }
          format.api  {
            @result = html
          }
        end
        
      ##
      # 
      # if other mime, then display result inline with filename and file size or download
      #
      else
        result = @script.run
        
        respond_to do |format|
        
          format.js   {
            html = script_out_filename(@script, result.length)
            render "act", :locals => {:html => html}
          }
          
          format.html { 
            if User.current.allowed_to?(:run_mime_scripts, nil, :global => true )
              send_data result,
                :filename    => filename_for_content_disposition( [@script.title, @script.ext].join ),
                :type        => @script.mime,
                :disposition => 'attachment'
            else
              html = script_out_filename(@script, result.length)
              flash[:notice] = html
              redirect_to :back
            end
          }
          
          format.api {
            if User.current.allowed_to?(:run_mime_scripts, nil, :global => true )
              send_data result,
                :filename    => filename_for_content_disposition( [@script.title, @script.ext].join ),
                :type        => @script.mime,
                :disposition => 'attachment'
            else
              render_api_head( :forbidden )
            end
          }
        end
        
      end
    end
    
  end #def
  
  ########################################################################################
  # fiddle with data from redmine
  ########################################################################################
  def fiddle
    
    determine_model
    common_params
    
    parameterize_script
    
    case @script.mime
    
    ##
    # 
    # if text/html, then display result inline or as extra page
    #
    when "text/html"
    
      if @script.html_safe? && User.current.allowed_to?(:run_html_fiddles, nil, :global => true )
        @html = embed_as_html(@script.run) # will be embedded as html_safe
      else
        @html = embed_as_text(@script.run) # will be embedded with CGI.escapeHTML
      end
      
      respond_to do |format|
        format.js   { }
        format.html { }
      end
      
    ##
    # 
    # if other mime, then display result as filename and file size inline or download
    #
    else
    
      result = @script.run
      
      respond_to do |format|
      
        format.js   {
          @html = script_out_filename(@script, result.length)
        }
        
        format.html { 
        
          if User.current.allowed_to?(:run_mime_fiddles, nil, :global => true )
            send_data result,
              :filename    => filename_for_content_disposition( [@script.title, @script.ext].join ),
              :type        => @script.mime,
              :disposition => 'attachment'
          else
            html = script_out_filename(@script, result.length)
            flash[:notice] = html
            redirect_to :back
          end
        }
      end
    end
  end #def
  
  
  ########################################################################################
  # run snippet with no data from redmine, for untrusted
  ########################################################################################
  def snippet
    common_params
    @html = embed_as_text(@script.run(false)) 
    respond_to do |format|
      format.js
      format.html
    end
  end ##def
  
  ########################################################################################
  #
  # private functions
  #
  ########################################################################################
  private
  
  ########################################################################################
  # find_script
  ########################################################################################
  def find_script
    # actually, this is a wiki page id
    @page = WikiPage.find(params[:id])
    raise Unauthorized unless @page.visible?
    @script = RedmineScript.compile( @page )
  rescue ActiveRecord::RecordNotFound
    render_404
  end #def
  
  ########################################################################################
  # build_script
  ########################################################################################
  def build_script
  
    ######################################################################################
    # if script is not signed, then user must have write script permission
    ######################################################################################
    if params[:signature].nil?
    
      type      = params[:type].to_s
      mime      = params[:mime].to_s
      script    = params[:script].to_s
      html_safe = POSITIVE_PARAMETER.include?(params[:html_safe])
      
      allowed = case params[:action]
      when 'snippet'
        # a snippt is always ruby and never html_safe
        User.current.allowed_to?(:write_snippets, @project, :global => @project.blank?) 
        
      when 'fiddle'
        # a fiddle may return plain, html or mime data
        case mime
        when "text/html"
          if html_safe
            # html output requested
            User.current.allowed_to?(:write_html_fiddles, @project, :global => @project.blank?)
          else
            # plain text output requested
            User.current.allowed_to?(:write_fiddles, @project, :global => @project.blank?)
          end
        else
          # mime output requested
          User.current.allowed_to?(:write_mime_fiddles, @project, :global => @project.blank?)
        end
      else
        false
      end
      
      raise Unauthorized unless allowed
      
    else
    ######################################################################################
    # if script is validly signed, then script can be run by others
    ######################################################################################
      signature            = params[:signature].to_s
      begin
        type, mime, script = verify_code(signature)
        
      rescue  ActiveSupport::MessageVerifier::InvalidSignature
        raise Unauthorized
      end
    end
    
    @script = RedmineScript.from_text( 
      script, type,
      :project => @project,
      :class   => @klass,
      :status  => status,
      :mime    => mime,
      :params  => script_parameter
    )
  end #def
  
  ########################################################################################
  # parameterize_script
  ########################################################################################
  def parameterize_script
    @script.eparams     = @eparams                           # params of embedding object
    @script.attachments = object_attachments(@embedding)     # digger will check visibility of @embedding
    @script.arguments   = script_args(@embedding, @objects ) # digger will check visibility of @objects
  end #def
  
  ########################################################################################
  # script_parameter
  ########################################################################################
  POSITIVE_PARAMETER = %w(1 ok yes true ✓)
  NEGATIVE_PARAMETER = %w(0 no false)
  def script_parameter
    params.permit(RedmineScript::ALLOWED_SCRIPT_PARAMETER).to_unsafe_hash.map do |p, value|
      if POSITIVE_PARAMETER.include?(value.downcase)
        p
      elsif NEGATIVE_PARAMETER.include?(value.downcase)
        nil
      end if value.is_a?(String)
    end.compact
  end #def
  
  ########################################################################################
  # find_objects
  ########################################################################################
  def find_objects
  
    @objects  = []
    @projects = []
    
    # leave @objects and @projects empty if :class and :ids are not provided
    return unless @klass = params.dig(:objects,:class).presence
    
    # leave @objects and @projects empty if :class and :ids are not properly formatted
    raise Inappropriate unless @klass.match?(/\A[A-Z][A-Za-z0-9]*\z/) # disallow Modules, etc
    
    # existing class only
    raise Inappropriate unless @klass = @klass.safe_constantize
    
    # leave @objects and @projects empty if :class and :ids are not provided
    return unless @ids = params.dig(:objects,:ids).presence
    
    # leave @objects and @projects empty if :class and :ids are not properly formatted
    raise Inappropriate unless (@ids.is_a?(Array) || @ids.is_a?(String))
    
    # only classes responding to :find
    raise Inappropriate unless @klass.respond_to?(:find)
    
    # furnish ids
    @ids = @ids.is_a?(Array) ? @ids.map{|id| id.split(/;|,|\ /)}.flatten : @ids.to_s.split(/;|,|\ /)
    @ids.select!(&:present?)
    raise Inappropriate if @ids.blank?
    
    # find visible objects only (not all classes have a :visible scope)
    @objects = @klass.find(@ids)
    raise Unauthorized unless @objects.all?{|obj| obj.try(:visible?)}
    
    # find projects of objects
    @projects = @objects.collect{|object| object.try(:project)}.compact.uniq
    
  rescue Inappropriate
    render_405
  rescue ActiveRecord::RecordNotFound
    render_404
  end #def
  
  ########################################################################################
  # common_params
  ########################################################################################
  def common_params
    @back         = params.permit(:back)[:back].presence
    @tag_id       = params.permit(:inline)[:inline].presence
    @embedding    = params.permit(:object => [:class, :id, :params => {}])[:object].to_h #.to_unsafe_hash
    @eparams      = params.permit(:eparams => {})[:eparams].to_h # params of embedding object
    @eparams      = JSON.parse(@eparams) rescue @eparams
    @mime         = params.permit(:mime)[:mime].presence
    @modal        = params.permit(:modal => {})[:modal].to_h # params of modal dialog
  end #def
  
  ########################################################################################
  # determine_model
  ########################################################################################
  def determine_model
    @model_name   = model_name
    @model_class  = model_class
    @model        = model
    @models       = models
  end #def
  
  ########################################################################################
  # model_name
  ########################################################################################
  def model_name
    model_string   = @objects.length == 1 ? model : models
    ::I18n.t("label_#{model_string}".to_sym, :default => ::I18n.t("label_#{model}_plural".to_sym, :default => model_string) )
  end #def
  
  ########################################################################################
  # model_class
  ########################################################################################
  def model_class
    @klass.try(:name)
  end #def
  
  ########################################################################################
  # model
  ########################################################################################
  def model
    model_class.try(:underscore)
  end #def
  
  ########################################################################################
  # models
  ########################################################################################
  def models
    model.try(:pluralize)
  end #def
  
  ########################################################################################
  # success_message
  ########################################################################################
  def success_message
    if @klass && @objects.length == 1
      content_tag(:span,
      content_tag(:span, "&nbsp;".html_safe, :class => @script.danger? ? "red" : "green") +
      l(:label_ran_script_at_singular,
        :level => @script.danger? ? l(:label_red) : l(:label_green),
        :name  => @script.title,
        :model => model_name 
       ))
    elsif @klass && @objects.length > 1
      content_tag(:span,
      content_tag(:span, "&nbsp;".html_safe, :class => @script.danger? ? "red" : "green") +
      l(:label_ran_script_at_plural, 
        :level => @script.danger? ? l(:label_red) : l(:label_green),
        :name  => @script.title,
        :count => @objects.length.to_s, 
        :model => model_name 
       ))
    else # @objects.length mus be zero, regardless of existence of @klass
      content_tag(:span,
      content_tag(:span, "&nbsp;".html_safe, :class => @script.danger? ? "red" : "green") +
      l(:label_ran_script, 
        :level => @script.danger? ? l(:label_red) : l(:label_green),
        :name  => @script.title
       ))
    end
  end #def
  
  ########################################################################################
  # script_sort_clause
  # creates a hash from sort clause
  #
  # 'title:desc,id:asc'
  #  to 
  # {title: 'desc', id: 'asc'}
  ########################################################################################
  def script_sort_clause
    sorts = params[:sort].to_s.split(/,/)
    sorts.map!{|s| s.split(/:/)}
    sorts.map!{|a| a[1].present? ? ( %w(asc desc).include?(a[1]) ? a : a + ['asc'] ) : a + ['asc'] }
    sorts
  end #def
  
  ########################################################################################
  # error pages
  ########################################################################################
  def render_405(options={})
    render_scripting_error({:message => l(:notice_inapproriate_type), :status => 405}.merge(options))
    return false
  end #def
  
  def deny_unauthorized_scripting(options={})
    @project = nil
    render_scripting_error({:message => :notice_not_authorized, :status => 403}.merge(options))
    return false
  end #def
  
  def log_exception(e)
    Rails.logger.info ([e.class.name] + [e.message] + e.backtrace).join("\n")
  end #def
  
  # Renders an error response
  def render_scripting_error(arg)
    arg = {:message => arg} unless arg.is_a?(Hash)

    @message = arg[:message]
    @message = l(@message) if @message.is_a?(Symbol)
    @status = arg[:status] || 500

    respond_to do |format|
      format.html {
        render :template => 'common/error', :layout => use_layout, :status => @status
      }
      format.js { render :action => "error" }
    end
  end
  
end #class