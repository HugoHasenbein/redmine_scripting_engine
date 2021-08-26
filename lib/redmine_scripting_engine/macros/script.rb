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
  
    include Redmine::I18n
    include RedmineScriptingEngine::Lib
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::UrlHelper
    
    Redmine::WikiFormatting::Macros.register do
    
        desc "Prints a script link in the current object page .\n" +
             "Added by RedmineScriptingEngine plugin.\n" +
             "parameters: \n" +
             "title: name of script or WikiPage id\n" +
             "Example:\n" +
             "{{script(My Script)}}"
             
        macro :script do |obj, args|
          
          ################################################################################
          # common strategy:
          #                  1. module enabled?
          #                  2. load helpers
          #                  3. get arguments
          #                  4. filter, set/unset options
          #                  5. language supported by Redmine's CodeRay?
          #                  6. create code
          #                  7. language supported by RedmineScriptingEngine (runnable? / (executable?))
          #                  8. user allowed?
          #                  9. in preview, disable buttons
          #                  
          ################################################################################
          project = @project || obj.try(:project)
          
          ################################################################################
          # 1. module enabled?
          ################################################################################
          return nil unless project && project.module_enabled?(:redmine_scripting_engine) 
          
          ################################################################################
          # 2. load helpers
          ################################################################################
          unless self.class.included_modules.include?( RedmineScriptingEngine::MacrosHelper )
          self.class.class_eval{ include RedmineScriptingEngine::MacrosHelper }
          end
          
          ################################################################################
          # 3. get arguments
          ################################################################################
          title = args.first
          
          ################################################################################
          # 4. filter, set/unset options
          ################################################################################
          # noop
          
          ################################################################################
          # check arguments
          ################################################################################
          dead_link  = content_tag(:a, title.presence || I18n.t(:label_none), 
                                   :class => "icon icon-dead-script", 
                                   :style => "color:grey;")
                                   
          if    title.blank?
            ##############################################################################
            # cannot continue with no script indication
            ##############################################################################
            return dead_link 
            
          elsif title.match?(/\A\d+\z/)
            ##############################################################################
            # cannot continue with non-existent script
            ##############################################################################
            page = WikiPage.visible.find(title) rescue nil
            return dead_link unless page
            
            script = RseWikiScript.compile( page )
          else
            ##############################################################################
            # cannot continue with non-existent script
            ##############################################################################
            script = RseWikiScript.find_for([obj], :title => title)
            
            return dead_link unless script.present?
          end
          
          script = script.is_a?(Array) ? script.first : script
          
          ################################################################################
          # 5. language supported?
          ################################################################################
          type = script.language; language = RSE_LANGUAGES[type]
          supported = Redmine::SyntaxHighlighting.language_supported?(language)
          return dead_link unless supported
          
          ################################################################################
          # 6. create code html
          ################################################################################
          # noop
          
          ################################################################################
          # 7. is code executable?
          ################################################################################
          executable  = RSE_SUPPORTED_TYPES.include?(type)
          return dead_link unless executable
          
          ################################################################################
          # 8. user allowed?
          ################################################################################
          return dead_link if  script.danger? && !User.current.allowed_to?(:run_red_scripts, obj.project)
          return dead_link if !script.danger? && !User.current.allowed_to?(:run_scripts,     obj.project)
          
          ################################################################################
          # 9 disable if in preview
          ################################################################################
          #noop, is deprecated in favor of #in_preview?
          
          ################################################################################
          # eventually, create script_link environment
          ################################################################################
          
          tag_id    = SecureRandom.uuid
          
          # create result pane
          pane      = result_pane(tag_id) if script.inline?
          
          # create submit form
          form_id   = SecureRandom.uuid
          
          ################################################################################
          # if the script has a modal pane, add modal container
          ################################################################################
          
          if script.modal? 
            modal_tag_id = SecureRandom.uuid + "_modal"
            modal_form_partial = textilizable(script.modal, :object => obj, :headings => false)
            
            modal_other_params = CGI.unescape({
                  :object  => {:class => obj.class.name, :id => obj.id, :params => {:url => request.url}},
                  :eparams => request.params,
                  :each    => (script.each? ? 1 : nil),
                  :sync    => (script.sync? ? 1 : nil),
                  :inline  => (script.inline? ? tag_id : nil),
                  :back    => request.original_url
                }.to_query).split(/&/).map{|kv| k,v = kv.split(/\=/); hidden_field_tag(k, v)}.join.html_safe
                
            modal = content_tag(:div, :id => "#{modal_tag_id}", :style => "display:none;") do
              form_tag( 
                _run_project_script_path(project, script.id),
                :method   => :get,
                :remote   => script.each?,
                :data     => script.danger? ? {:confirm => l(:text_are_you_sure)} : nil,
                :onsubmit => "hideModal(this);".html_safe
              ) do
                content_tag(:div, :class => "box tabular") do
                  modal_form_partial + modal_other_params
                end + submit_tag(l(:button_submit), :disabled => in_preview?)
              end 
            end
            
            link_to( script.title, "",
                    :class    => "icon " + (script.danger? ? "icon-danger-script" : "icon-script"), 
                    :onclick  => "showModal('#{modal_tag_id}', '600px'); return false;",
                    :disabled => in_preview?
            ) + modal + pane
            
          else
            ##############################################################################
            # just build link
            ##############################################################################
            link_to( 
              script.title, 
              _run_project_script_path(project, script.id,
                :object     => {:class => obj.class.name, :id => obj.id, :params => {:url => request.url}},
                :eparams    => {:url => request.url, :params => request.params},
                :each       => (script.each? ? 1 : nil),
                :sync       => (script.sync? ? 1 : nil),
                :inline     => (script.inline? ? tag_id : nil),
                :back       => request.original_url
              ), 
              :class    => "icon " + (script.danger? ? "icon-danger-script" : "icon-script"), 
              :data     => script.danger? ? {:confirm => l(:text_are_you_sure)} : nil,
              :remote   => script.each?,
              :disabled => in_preview?
             ) + pane
           end
        end #macro
        
    end #register
    
  end #module
end #module
