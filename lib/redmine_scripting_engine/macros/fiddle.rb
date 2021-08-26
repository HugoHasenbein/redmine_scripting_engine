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
    
        desc "Formats a fiddle and prints a try button.\n" +
             "Added by RedmineScriptingEngine plugin.\n" +
             "parameters: \n" +
             "type:         code type, i.e ruby, shell, python or perl\n" +
             "html_safe=:   optional parameter: returns html (needs permission)\n" +
             "mime=:        optional parameter: returns mime (needs permission)\n" +
             "confirm=:     optional parameter: ask for confirmation on submit\n" +
             "numbering=:   optional parameter: prints code with line numbers\n" +
             "autoheight=:  optional parameter: auto height or fixed (for promiscuous mode)\n" +
             "promiscuous=: optional parameter: code can be changed without saving\n" +
             "liblines=:    optional parameter: respect library lines for numbering\n" +
             "text:         code to run in fiddle\n" +
             "Example:\n" +
             "{{fiddle(ruby, html_safe=1,confirm=1,numbering=1)\n" +
             "1 + 2\n" +
             "}}"
             
        macro :fiddle do |obj, args, text|
          
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
          return nil unless project.try(:module_enabled?, :redmine_scripting_engine) 
          
          ################################################################################
          # 2. load helpers
          ################################################################################
          unless self.class.included_modules.include?( RedmineScriptingEngine::MacrosHelper )
          self.class.class_eval{ include RedmineScriptingEngine::MacrosHelper }
          end
          
          ################################################################################
          # 3. get arguments
          ################################################################################
          args, options = extract_macro_options(args, 
            :html_safe, 
            :confirm, 
            :numbering,
            :autoheight, 
            :mime,
            :promiscuous,
            :liblines)
            
          ################################################################################
          # 4. filter, set/unset options
          ################################################################################
          type          = args[0].to_s; language = RSE_LANGUAGES[type]
          # mime takes precedence over html
          html_safe     = boolean_string( options[:html_safe]) && !options[:mime]
          confirm       = boolean_string( options[:confirm])
          numbering     = boolean_string( options[:numbering])
          promiscuous   = boolean_string( options[:promiscuous])
          autoheight    = boolean_string( options[:autoheight])
          mime          = options[:mime]
          liblines      = boolean_string( options[:liblines])
          
          ################################################################################
          # count total lines in all ancestor libs
          ################################################################################
          if liblines 
            liblines = RedmineScriptingEngine::Lib::RseWikiScript.
              wikiscript_libs(project, language).
              map{|ancestor,lib| lib }.
              join("\n").split(/\n/).length 
          else
            liblines = 0
          end
          
          ################################################################################
          # check arguments
          ################################################################################
          html_safe     = (Setting["plugin_redmine_scripting_engine"]["enable_html"].to_i > 0) && html_safe
          mime          = (Setting["plugin_redmine_scripting_engine"]["enable_mime"].to_i > 0) && mime
          ajax          = !mime # if mime is set, then dont't make an ajax call
          
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
          preclasses =  "fiddle #{type}"
          preclasses << " red"  if confirm
          preclasses << " html" if html_safe
          preclasses << " mime" if mime
          code = format_code(text, 
            :language => language, 
            :numbering => numbering, 
            :line_num => liblines + 1,
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
          # is user allowed to run fiddles?
          allowed   = User.current.allowed_to?(:run_fiddles, nil, :global => true)
          hallowed  = User.current.allowed_to?(:run_html_fiddles, nil, :global => true)
          mallowed  = User.current.allowed_to?(:run_mime_fiddles, nil, :global => true)
          
          # return just code, if user is not allowed to run any, no uggly error message
          return code unless allowed || hallowed || mallowed
          
          # return dead text, if fiddle is html and user may not run html fiddles
          return dead_code_button( code,
            :notice_html_not_permitted,
            :code => true ) if html_safe && !hallowed
          
          # return dead text, if fiddle returns mime and user may not run mime fiddles
          return dead_code_button( code,
            :notice_mime_not_permitted,
            :code => true ) if mime && !mallowed
          
          ################################################################################
          # 9 disable if in preview
          ################################################################################
          #noop, is deprecated in favor of #in_preview?
          
          ################################################################################
          # eventually, create fiddle environment
          ################################################################################
          
          tag_id    = SecureRandom.uuid
          
          # create result pane
          pane      = result_pane(tag_id)
          
          # create submit form
          form_id   = SecureRandom.uuid
          
          # add event listener, that shows ajax indicator on click for ajax calls
          indicator_on_confirm_click( form_id ) if (confirm && ajax) # if ajax
          
          # add CodeMirror headers for promiscuous mode
          if promiscuous
            editor_id = form_id + "_editor"
            codemirror_headers(language)
          end
          
          # apparently, data: {confirm "text"} needs to be added in form for ajax calls
          # and needs to be aded in button for non-ajax calls
          form      =
          content_tag(:pre, :class => promiscuous ? "fiddle src #{type} src-#{language}" : "button") do
            form_tag(_fiddle_project_scripts_path(project), 
              :method     => "post", 
              :id         => form_id, 
              :remote     => ajax,
              :data       => (confirm && ajax) ? {:confirm => l(:text_are_you_sure)} : nil,
              :onsubmit   => (confirm && ajax) ? nil : ajax ? "$('#ajax-indicator').show();" :nil
            ) do
              [ hidden_field_tag(:back,   request.original_url),
                hidden_field_tag(:type,   CGI::escapeHTML("#{type}")),
               (hidden_field_tag(:mime, mime ) if mime.present?),
                hidden_field_tag(:inline, tag_id),
                
                # signed code is type, mime, script
               (hidden_field_tag(:signature, sign_code([type, mime.to_s, text])) unless promiscuous),
               (hidden_field_tag(:script,    text)                               unless promiscuous),
               (text_area_tag(   :script,    text, :id => editor_id)             if     promiscuous),
               
                html_safe ? hidden_field_tag(:html_safe, "1") : "",
                hidden_field_tag('object[class]', obj.class.name),
                hidden_field_tag('object[id]', obj.id),
                hidden_field_tag('object[params][url]', request.url),
                hidden_field_tag('eparams[url]', request.url),
                request.params.map do |param, val|
                hidden_field_tag("eparams[params][#{param}]", val)
                end,
                submit_tag( l(:button_try), 
                  :disabled => in_preview?, 
                  :class    => mime.present? ? "icon icon-download" : nil, 
                  :data     => (confirm && !ajax) ? {:confirm => l(:text_are_you_sure)} : nil
                )
              ].flatten.join.html_safe
            end
          end #form
          
          if promiscuous
            form + pane + instantiate_codemirror( editor_id, 
            { autoheight:      autoheight,
              lineNumbers:     numbering, 
              firstLineNumber: liblines + 1, 
              readOnly:        in_preview?, 
              mode:            RSE_CODEMIRROR_MIMES[language],
              theme:          'elegant'
            }.compact ) 
          else
            code + form + pane
          end
          
        end #macro
        
    end #register
    
  end #module
end #module
