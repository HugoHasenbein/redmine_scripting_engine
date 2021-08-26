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
    
        desc "Formats a pure ruby snippet and prints a run button.\n" +
             "Added by RedmineScriptingEngine plugin.\n" +
             "parameters: \n" +
             "confirm=:     optional parameter: ask for confirmation on submit\n" +
             "numbering=:   optional parameter: prints code with line numbers\n" +
             "autoheight=:  optional parameter: if promiscuous: auto height or fixed\n" +
             "promiscuous=: optional parameter: code can be changed without saving\n" +
             "text: snippet to run\n" +
             "Example:\n" +
             "{{snippet(confirm=1,numbering=1)\n" +
             "1 + 2\n" +
             "}}"
             
          
        macro :snippet do |obj, args, text|
          
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
          # 1. module enabled? # snippets also work on home / projects / project overview 
          #                    # (obj is nil)
          ################################################################################
          return nil unless project.try(:module_enabled?, :redmine_scripting_engine) || 
                            obj.nil?
                            
          ################################################################################
          # 2. load helpers
          ################################################################################
          unless self.class.included_modules.include?( RedmineScriptingEngine::MacrosHelper )
          self.class.class_eval{ include RedmineScriptingEngine::MacrosHelper }
          end
          
          ################################################################################
          # 3. get arguments
          ################################################################################
          args, options = extract_macro_options(args, :confirm, :numbering, :autoheight,
                                                      :promiscuous)
          
          ################################################################################
          # 4. filter, set/unset options
          ################################################################################
          type          = args[0].to_s.underscore; language = RSE_LANGUAGES[type]
          confirm       = boolean_string( options[:confirm])
          numbering     = boolean_string( options[:numbering])
          promiscuous   = boolean_string( options[:promiscuous])
          autoheight    = boolean_string( options[:autoheight])
          
          ################################################################################
          # check arguments
          ################################################################################
          #noop
          
          ################################################################################
          # 5. language supported?
          ################################################################################
          supported = Redmine::SyntaxHighlighting.language_supported?(language)
          return dead_code_button( text, 
            :notice_syntax_not_supported, 
            :language => type) unless supported
          
          ################################################################################
          # 6. create code html
          ################################################################################
          preclasses =  "snippet #{type}"
          preclasses << " red"  if confirm
          code = format_code(text, 
            :language => language, 
            :numbering => numbering, 
            :preclass => preclasses)
          
          ################################################################################
          # 7. is code executable?
          ################################################################################
          executable  = RSE_SUPPORTED_TYPES.include?(type)
          return dead_code_button( code, 
            :notice_code_not_runnable, 
            :language => type,
            :code => true ) unless executable
          
          ################################################################################
          # 8. user allowed?
          ################################################################################
          allowed       = User.current.allowed_to?(:run_snippets, nil, :global => true)
          # return just code, if user is not allowed to run any, no uggly error message
          return code unless allowed
          
          ################################################################################
          # 9 disable if in preview # obsolete, now use macro_helper#in_preview?
          ################################################################################
          #noop, is deprecated in favor of #in_preview?
          
          ################################################################################
          # eventually, create snippet environment
          ################################################################################
          
          tag_id        = SecureRandom.uuid
          
          # create result pane
          pane          = result_pane(tag_id)
          
          # create submit form
          form_id   = SecureRandom.uuid
          
          # add event listener, that shows ajax indicator on confirm click
          indicator_on_confirm_click( form_id )
          
          # add CodeMirror headers for promiscuous mode
          if promiscuous
            editor_id = form_id + "_editor"
            codemirror_headers(language)
          end
          
          form      =
          content_tag(:pre, :class => promiscuous ? "snippet src #{type} src-#{language}" : "button") do
            form_tag(_snippet_project_scripts_path(project), 
              :method     => "post", 
              :id         => form_id, 
              :remote     => true,
              :data       => confirm ? {:confirm => l(:text_are_you_sure)} : nil,
              :onsubmit   => confirm ? nil : "$('#ajax-indicator').show();"
            ) do
              [ hidden_field_tag(:back,      request.original_url),
                hidden_field_tag(:inline,    tag_id),
                hidden_field_tag(:type,      CGI::escapeHTML("#{type}")),
                # signed code is type, mime, script
               (hidden_field_tag(:signature, sign_code([type, "", text])) unless promiscuous),
               (hidden_field_tag(:script,    text)                        unless promiscuous),
               (text_area_tag(   :script,    text, :id => editor_id)      if     promiscuous),
                submit_tag(l(:button_try), :disabled => in_preview? )
              ].join.html_safe
            end
          end #form
          
          if promiscuous
            form + pane + instantiate_codemirror( editor_id, 
            { autoheight:  autoheight,
              lineNumbers: numbering, 
              readOnly:   in_preview?, 
              mode:       RSE_CODEMIRROR_MIMES[language],
              theme:     'elegant'
            }.compact ) 
          else
            code + form + pane
          end
          
        end #macro
        
    end #register
    
  end #module
end #module
