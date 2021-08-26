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
    
        desc "Prints a try link in the current wiki page to try a Wikiscript.\n" +
             "Added by RedmineScriptingEngine plugin.\n" +
             "Only works on a wiki page.\n" +
             "parameters: \n" +
             "class=:  name of an object class to run the script with\n" +
             "ids=:    space separated list of class object ids to run the script with\n"+
             "each=:   if set, then script runs for each object individually, overrides Wikiscript parameters\n" +
             "sync=:   if set, then script runs for each object individually, synchronously, overrides Wikiscript parameters\n" +
             "inline=: if set, then script runs inline, overrides Wikiscript parameters\n"
             "Example:\n" +
             "{{try(class=Issue,ids=1 2 3,inline=1)}}"
             
             
        macro :try do |obj, args|
        
          ################################################################################
          # common strategy:
          #                  1. module enabled?
          #                  2. load helpers
          #                  3. get arguments
          #                  4. filter, set/unset options
          #                  5. language supported by Redmine's CodeRay?
          #                  6. create code
          #                  7. language supported by RedmineScriptingEngine (executable?)
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
          # obj is wiki content?
          ################################################################################
          return dead_code_button( code, 
            :notice_only_wikipage_supported, 
            :language => language,
            :code => true ) unless obj.is_a?(WikiContent)
                                  
          ################################################################################
          # 3. get arguments
          ################################################################################
          args, options = extract_macro_options(args, :class, :ids, :each, :sync, :inline)
          
          ################################################################################
          # 4. filter, set/unset options
          ################################################################################
          klass    = options[:class]
          each     = options[:each  ].nil? || boolean_string( options[:each  ])
          sync     = options[:sync  ].nil? || boolean_string( options[:sync  ])
          inline   = options[:inline].nil? || boolean_string( options[:inline])
          ids      = options[:ids].to_s.split(/;|,|\ /)
          
          ################################################################################
          # check arguments
          ################################################################################
          script   = RseWikiScript.compile( obj.page )
          type = script.type; language = RSE_LANGUAGES[type]
          
          ################################################################################
          # 5. language supported?
          ################################################################################
          supported = Redmine::SyntaxHighlighting.language_supported?(language)
          return unsupported_code_button( "", 
            :notice_syntax_not_supported, 
            :language => language) unless supported
          
          ################################################################################
          # 6. create code html
          ################################################################################
          preclasses =  " try"
          preclasses << " red"  if script.red?
          preclasses << " html" if script.html_safe?
          preclasses << " mime" if script.mime?
          
          ################################################################################
          # 7. is code executable?
          ################################################################################
          executable  = RSE_SUPPORTED_TYPES.include?(language)
          return dead_code_button( code, 
            :notice_code_not_runnable, 
            :language => language,
            :code => true ) unless executable
          
          ################################################################################
          # 8. user allowed?
          ################################################################################
          # is user allowed to run tries?
          allowed  = User.current.allowed_to?(:run_tries, obj.project)
          
          # return nothing, if user is not allowed to run tries, no uggly error message
          return "" if !allowed
          
          ################################################################################
          # 9. disable if in preview
          ################################################################################
          #noop, is deprecated in favor of #in_preview?
          
          ################################################################################
          # eventually, create try environment
          ################################################################################
          
          tag_id    = SecureRandom.uuid
          
          # create result pane
          pane      = result_pane(tag_id)
          
          # create submit form
          form_id   = SecureRandom.uuid
          
          # create javascript - must be contained in :onclick attribute to prevent showing up in pdf export
          js = <<-EOF.strip_heredoc
            function toggleRemote(form) {
              var each   = $(form).find("input[type='checkbox'][name='each']").prop('checked');
              var inline = $(form).find("input[type='checkbox'][name='inline']").prop('checked');
              if( each && inline ) {
                 $(form).attr('data-remote', true);
              } else {
                 $(form).attr('data-remote', false);
              }
            }
            function toggleEachSync(form) {
              $(form).find("label[for='sync']").toggle();
              $(form).find("input[type='checkbox'][name='sync']").toggle();
              $(form).find("label[for='inline']").toggle();
              $(form).find("input[type='checkbox'][name='inline']").toggle();
            }
          EOF
          
          cpjs = <<-EOF.strip_heredoc
            function mergeForm(from, to) {
              var from_data = $(from).parents('form').serializeArray();
              var tags = "";
              for(var index in from_data) {
                tags += ("<input name='"+ from_data[index]['name'] + "' type='hidden' value='" + from_data[index]['value'] + "' />");
              };
              $(to).html(tags);
            }
          EOF
          
          # cpjs_tag = javascript_tag(cpjs)
          
          # create form
          modal_tag_id = SecureRandom.uuid # only needed, if script is modal
          
          form =
          content_tag(:div, :class => "pre " + preclasses) do
            form_tag(run_project_script_path(:project_id => obj.project.identifier, :id => obj.page.id), 
              :method => "get", 
              :id => form_id, 
              :remote => each && inline,
              :data => script.danger? ? {:confirm => l(:text_are_you_sure)} : nil
            ) do
             [ hidden_field_tag(:back, wiki_page_path(obj.page)),
               hidden_field_tag(:inline, inline ),
               hidden_field_tag("object[class]", obj.class.name ),
               hidden_field_tag("object[id]", obj.try(:id) ),
               hidden_field_tag('object[params][url]', request.url),
               hidden_field_tag('eparams[url]', request.url),
               hidden_field_tag('eparams[params]', request.params),
                label_tag("objects[class]",  "Class"  ), 
                 text_field_tag("objects[class]",  klass, :size => 10),
               label_tag("objects[ids]_",   "Ids"    ), 
                 text_field_tag("objects[ids][]",  ids,   :size => 5),
               label_tag("each",   "Each"   ), 
                 check_box_tag( "each",   1,      each,   :onclick=>"#{js.squish}; toggleEachSync('##{form_id}'); toggleRemote('##{form_id}')"),
               label_tag("sync",   "Sync",                :style => each ? "" : "display:none;"), 
                 check_box_tag( "sync",   1,      sync,   :style => each ? "" : "display:none;"),
               label_tag("inline", "Inline",              :style => each ? "" : "display:none;"), 
                 check_box_tag( "inline", tag_id, inline, :style => each ? "" : "display:none;", :onclick=>"#{js.squish}; toggleRemote('##{form_id}')"),
               submit_tag(l(:button_try), 
                 :disabled => in_preview?, 
                 :class => script.mime? ? "icon icon-downlaod" : nil, 
                 :onclick => script.modal? ? "#{cpjs.squish};mergeForm(this, '##{form_id}_copy');showModal('#{modal_tag_id}', '600px'); return false" : "")
              ].join(" ").html_safe
            end 
          end
          
          if script.modal?
            
            modal_form_partial = textilizable(script.modal, :object => obj, :headings => false)
            modal = content_tag(:div, :id => "#{modal_tag_id}", :style => "display:none;") do
              form_tag( 
                run_project_script_path(obj.project.identifier, script.id),
                :id       => "#{modal_tag_id}_form",
                :method   => :get,
                :remote   => script.each?,
                :data     => script.danger? ? {:confirm => l(:text_are_you_sure)} : nil,
                :onsubmit => "hideModal(this);".html_safe
              ) do
                content_tag(:div, :class => "box tabular") do
                  modal_form_partial
                end + 
                content_tag(:div, "", :class => "pre", :id => "#{form_id}_copy" ) +
                submit_tag(l(:button_submit), :disabled => in_preview? )
              end 
            end
            
            return form + pane + modal # + cpjs_tag
            
          else
            return form + pane # + cpjs_tag
          end
          
        end #macro
        
    end #register
    
  end #module
end #module
