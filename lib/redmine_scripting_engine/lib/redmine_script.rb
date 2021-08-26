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

# require 'trusted_sandbox'

class RedmineScript
  
  ########################################################################################
  #
  # includes
  #
  ########################################################################################
  include RedmineScriptingEngine::Lib
  include RedmineScriptingEngine::Lib::RseUtils
    
  ########################################################################################
  #
  # delegates
  #
  ########################################################################################
  delegate :url_for, :to => "Rails.application.routes.url_helpers"
  
  ########################################################################################
  #
  # constants
  #
  ########################################################################################
  ALLOWED_SCRIPT_PARAMETER = %w(each sync inline danger html_safe)
  
  ########################################################################################
  #
  # instance functions
  #
  ########################################################################################
  attr_reader   :project, :page_id, :author_id, :title, :klass, :permission, :status, 
                :script, :type, :params, :modal, :mime, :editable
  attr_accessor :arguments, :attachments, :eparams, :response
  
  def initialize(options={})
    @project     = options[:project]
    @page_id     = options[:page_id]
    @author_id   = options[:author_id]
    @editable    = options[:editable]
    @title       = options[:title]
    @klass       = options[:class]
    @permission  = options[:permission]
    @status      = options[:status]
    @script      = options[:script]
    @type        = options[:type].presence || "ruby"
    @mime        = options[:mime].presence
    @params      = options[:params]        # each sync inline html_safe
    @eparams     = options[:eparams]       # parameter of embedding object
    @modal       = options[:modal]
    @arguments   = options[:arguments].to_h
    @attachments = options[:attachments].to_a
  end #def
  
  ########################################################################################
  # to_s
  ########################################################################################
  def to_s
    title
  end #def
  
  ########################################################################################
  # to_s
  ########################################################################################
  def css_classes
    css  = "wikiscript"
    css << " red" if red?
    css << " green" if green?
    css << " green" if green?
  end #def
  
  ########################################################################################
  # id
  ########################################################################################
  def id
    page_id
  end #def
  
  ########################################################################################
  # page
  ########################################################################################
  def page
    if page_id
      Wiki.find_page(page_id, :project => project) rescue nil
    end
  end #def
  
  ########################################################################################
  # page
  ########################################################################################
  def author
    if author_id
      User.find(author_id) rescue nil
    end
  end #def
  
  ########################################################################################
  # permission_required?
  ########################################################################################
  def permission_required?
    permission.present?
  end #def
  
  ########################################################################################
  # permitted?
  ########################################################################################
  def permitted?(project, user=User.current)
    permission.to_a.all?{|p| user.allowed_to?(p.to_sym, project, :global => project.blank? )}
  end #def
  
  ########################################################################################
  # params functions
  ########################################################################################
  def params?(param)
    @params.to_a.map(&:downcase).include?(param.downcase)
  end #def
  
  ########################################################################################
  # each? 
  ########################################################################################
  def each?
    return true if params?("each") 
  end #def
  
  ########################################################################################
  # sync?
  ########################################################################################
  def sync?
    return true if params?("sync") 
  end #def
  
  ########################################################################################
  # inline?
  ########################################################################################
  def inline?
    return true if params?("inline") 
  end #def
  
  ########################################################################################
  # danger?
  ########################################################################################
  def danger?
    return true if params?("danger") || params?("red")
  end #def
  def red?;    danger?; end #def
  def green?; !danger?; end #def
  alias :red :red?
  alias :green :green?
  
  ########################################################################################
  # html_safe?
  ########################################################################################
  def html_safe?
    return true if params?("html_safe") && Setting["plugin_redmine_scripting_engine"]["enable_html"].to_i > 0 
    # this parameter is used to mark html_safe output
  end #def
  
  ########################################################################################
  # modal?
  ########################################################################################
  def modal?
    @modal.present?
  end #def
  
  ########################################################################################
  # mime
  ########################################################################################
  def mime
    if Setting["plugin_redmine_scripting_engine"]["enable_mime"].to_i > 0
      @mime ||= "text/html" 
    else
      "text/html"
    end 
  end #def
  
  def mime?
    mime.nil? || mime != "text/html"
  end #def
  
  def ext
    return ".bin" if mime == "application/octet-stream"
    Rack::Mime::MIME_TYPES.invert[mime] || ".bin"
  end #def
  
  ########################################################################################
  # language
  ########################################################################################
  def language
    type.to_s.underscore
  end #def
  
  ########################################################################################
  # attributes
  ########################################################################################
  def attributes
    {:project     => project,
     :page_id     => page_id,
     :author_id   => author_id,
     :editable    => editable,
     :title       => title,
     :klass       => klass,
     :permission  => permission,
     :status      => status,
     :red         => red,
     :script      => script,
     :type        => type,
     :mime        => mime,
     :ext         => ext,
     :params      => params,               # each sync inline html_safe
     :eparams     => eparams,              # parameter of embedding object
     :modal       => modal,
     :arguments   => arguments.to_h, 
     :attachments => attachments.to_a
    }
  end #def
  
  ########################################################################################
  # reflect_on_all_associations: mimic functions of ActiveRecord
  ########################################################################################
  def self.reflect_on_all_associations
    []
  end #def
  
  ########################################################################################
  # find
  ########################################################################################
  def self.find(args)
    wiki_pages = WikiPage.find(Array(args))
    wiki_pages.map{|page| compile(page)}
  end #def
  
  ########################################################################################
  # compile
  ########################################################################################
  def self.compile( page )
  
    title         = RseWikiScan.page_titles(    page ).first
    klasses       = RseWikiScan.section_words(  page, "Class" ).presence || [RseWikiScript::WILDCARD]
    permissions   = RseWikiScan.section_words(  page, "Permission" ).presence
    mime          = RseWikiScan.section_words(  page, "Mime" ).first.presence
    statuses      = RseWikiScan.section_words(  page, "Status" ).presence || [RseWikiScript::WILDCARD]
    script        = RseWikiScan.section_code(   page, "Script" )
    type          = RseWikiScan.code_type(      page, "Script" )
    params        = RseWikiScan.section_words(  page, "Parameter" )
    modal         = RseWikiScan.section_text(   page, "Modal" )
    mime          = RseWikiScan.section_words(  page, "Mime" ).first.presence
    
    new(
      :project     => page.project, 
      :page_id     => page.id,
      :author_id   => page.content.author.id,
      :editable    => page.editable_by?(User.current),
      :title       => title, 
      :klass       => klasses,
      :permission  => permissions,
      :status      => statuses,
      :params      => params,
      :modal       => modal,
      :script      => script,
      :type        => type,
      :mime        => mime,
      :arguments   => {},
      :attachments => {}
    )
  end #def
  
  ########################################################################################
  # simple
  ########################################################################################
  def self.from_text( text, type, options={} )
  
    title         = ::I18n.t(:label_fiddle)
    klass         = options[:class]
    project       = options[:project]
    permission    = options[:permission]
    status        = options[:status]
    params        = options[:params]  # each sync inline html_safe
    eparams       = options[:eparams] # params of embedding object
    mime          = options[:mime]
    
    new(
      :project     => project, 
      :page_id     => nil,
      :author_id   => nil,
      :editable    => false,
      :title       => title, 
      :klass       => klass,
      :permission  => permission,
      :status      => status,
      :params      => params,  # each sync inline html_safe
      :eparams     => eparams, # params of embedding object
      :modal       => nil,
      :script      => text,
      :type        => type,
      :mime        => mime
    )
  end #def
  
  ########################################################################################
  #
  # execute functions
  #
  ########################################################################################
  def run(api=true)
  
    
    begin
    
      if api
        libs = RedmineScriptingEngine::Lib::RseWikiScript.
          wikiscript_libs(project, type).
            map{|ancestor,lib| lib.strip_heredoc}.
              join("\n")
              
        response = RseDocker::Launcher.run_with_options(
          {'create'    => {'NetworkDisabled' => false}}, 
          :script      => "#{libs}\n#{script}", 
          :type        => type, 
          :args        => arguments,
          :attachments => attachments
        )
      else
        response = RseDocker::Launcher.run(
            :script      => script, 
            :type        => type, 
            :args        => {}, 
            :attachments => []
          )
      end
    
    rescue Exception => e
      response = error_response(e)
    end
    
    case response.status
    when 0 # no error
      response.output
    else
      Rails.logger.info response.error.message
      Rails.logger.info response.error.backtrace.join("\n")
      ([response.error.message] + response.error.backtrace).join("\n") 
    end
    
  end #def
  
  ########################################################################################
  #
  # private functions
  #
  ########################################################################################
  private
  
#   def os_arguments
#     JSON.parse({
#       :type => type,
#       :mime => mime
#       }.merge(arguments).to_json, object_class:OpenStruct)
#   end #def
  
#   def snippet_arguments
#     JSON.parse({
#       :type => type
#       }.to_json, object_class:OpenStruct)
#   end #def
  
end #class