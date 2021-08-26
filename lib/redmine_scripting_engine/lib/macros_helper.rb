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
  module MacrosHelper
  
    ######################################################################################
    # returns paths depending on availability of project
    ######################################################################################
    def _run_project_scripts_path(project, *args)
      project ? run_project_script_path(project.identifier, *args) : run_script_path(*args)
    end #def
    
    def _run_project_script_path(project, id, *args)
      project ? run_project_script_path(project.identifier, id, *args) : run_script_path(id, *args)
    end #def
    
    def _fiddle_project_scripts_path(project, *args)
      project ? fiddle_project_scripts_path(project.identifier, *args) : fiddle_scripts_path(*args)
    end #def
    
    def _snippet_project_scripts_path(project, *args)
      project ? snippet_project_scripts_path(project.identifier, *args) : snippet_scripts_path(*args)
    end #def
    
    ######################################################################################
    # checks, if macro runs in a preview pane
    ######################################################################################
    def in_preview?
      controller.class == PreviewsController || params[:action] == "preview"
    end #def
    
    ######################################################################################
    # interprets a string as a boolean value
    ######################################################################################
    def boolean_string(str)
      return nil   unless str.is_a?(String)
      return true  if %w(1 ok y yes t true ✓).include?(str.downcase)
      return false if %w(0 no n f false nil).include?(str.downcase)
      return nil
    end #def
    
    ######################################################################################
    # formats code plain or as numbered table
    ######################################################################################
    def format_code(code, **options)
    
      numbering = options[:numbering]
      language  = options[:language] || "ruby"
      preclass  = options[:preclass].to_s + " src src-#{language}"
      line_num  = (options[:line_num] || 1).to_i
      
      code      = code.to_s.encode(universal_newline:true)
      
      if numbering
        pane      = 
        content_tag(:div, :class => "pre #{preclass}") do
          content_tag(:table, :class => "language #{language} syntaxhl") do
            content_tag(:tbody) do
              Redmine::SyntaxHighlighting.highlight_by_language(code, language).split(/\n/).map.with_index(line_num) do |line, index|
                content_tag(:tr, :id => "L #{index}") do
                  content_tag(:th, :class => "line-num") do
                    content_tag(:a, index, :href => "#L #{index}")
                  end +
                  content_tag(:td, :class => "line-code") do
                    content_tag(:pre, line.html_safe)
                  end
                end
              end.join("\n").html_safe
            end
          end
        end
      else
        pane =
          content_tag(:pre, :class => preclass) do
            content_tag(:code, :class => "language #{language} syntaxhl") do
              Redmine::SyntaxHighlighting.highlight_by_language(code.encode(universal_newline:true), language).html_safe
            end
          end
      end
      
      pane
      
    end #def
    
    ######################################################################################
    # signs / verifies code
    ######################################################################################
    def sign_code(code)
      ActiveSupport::MessageVerifier.new(
        RedmineApp::Application.config.secret_key_base
      ).generate(code)
    end #def
    
    def verify_code(signature)
        ActiveSupport::MessageVerifier.new(
          RedmineApp::Application.config.secret_key_base
        ).verify(signature)
      # will raise ActiveSupport::MessageVerifier::InvalidSignature
    end #def
    
    ######################################################################################
    # prints CodeMirror editor
    ######################################################################################
    def codemirror_headers( type, **options )
      
      ####################################################################################
      # load all global files, which can be resused between individual code editors
      ####################################################################################
      content_for :header_tags do
        
        @codemirror_main_headers_sent = true
        
        # main component
        javascript_include_tag("#{RSE_CODEMIRROR_VERSION}/lib/codemirror.js", :plugin => :redmine_scripting_engine) +
        # main styling
        stylesheet_link_tag("/plugin_assets/redmine_scripting_engine/javascripts/#{RSE_CODEMIRROR_VERSION}/lib/codemirror.css") +
        
        # load theme
        codemirror_theme_css('elegant') +
        
        # search module addons
        codemirror_addon_js("search/search") +
        codemirror_addon_js("search/searchcursor") +
        codemirror_addon_js("search/jump-to-line") +
        codemirror_addon_js("dialog/dialog") + codemirror_addon_css("dialog/dialog") +
        codemirror_addon_js("scroll/annotatescrollbar") +
        codemirror_addon_js("search/matchesonscrollbar") + codemirror_addon_css("search/matchesonscrollbar") +
        
        # code folde addons
        codemirror_addon_js("fold/foldcode") +
        codemirror_addon_js("fold/foldgutter") + codemirror_addon_css("fold/foldgutter") +
        codemirror_addon_js("fold/brace-fold") +
        codemirror_addon_js("fold/comment-fold") +
        codemirror_addon_js("fold/indent-fold") +
        codemirror_addon_js("fold/xml-fold") + 
        
        # error_catcher
        error_catcher
        
      end unless defined?(@codemirror_main_headers_sent).present?
      
      ####################################################################################
      # load all global files for one specific language, which can be shared among editors
      ####################################################################################
      @codemirror_type_headers_sent = {} unless defined?(@codemirror_type_headers_sent).present?
      
      content_for :header_tags do
        @codemirror_type_headers_sent[type] = true
        # script type specific highlighting
        codemirror_mode_js(type)
      end if RSE_SUPPORTED_TYPES.include?(type) && !@codemirror_type_headers_sent[type]
      
    end #def
    
    def codemirror_mode_js(mode)
      javascript_include_tag("#{RSE_CODEMIRROR_VERSION}/mode/#{RSE_CODEMIRROR_MODES[mode]}/#{RSE_CODEMIRROR_MODES[mode]}.js", :plugin => :redmine_scripting_engine) 
    end #de
    
    def codemirror_addon_js(addonpath)
      javascript_include_tag("#{RSE_CODEMIRROR_VERSION}/addon/#{addonpath}.js", :plugin => :redmine_scripting_engine)
    end #def
    
    def codemirror_addon_css(addonpath)
      stylesheet_link_tag("/plugin_assets/redmine_scripting_engine/javascripts/#{RSE_CODEMIRROR_VERSION}/addon/#{addonpath}.css")
    end #def
    
    def codemirror_theme_css(addonpath)
      stylesheet_link_tag("/plugin_assets/redmine_scripting_engine/javascripts/#{RSE_CODEMIRROR_VERSION}/theme/#{addonpath}.css")
    end #def
    
    ######################################################################################
    # adds script to add editor to text area
    ######################################################################################
    def instantiate_codemirror( editor_id, **options )
      autoheight = options.delete(:autoheight)
      js = <<-EOF.strip_heredoc
              const target_#{editor_id.gsub(/-/,'')} = {}; 
              $('document').ready( function(){ 
                CodeMirror.fromTextArea(
                 $('##{editor_id}')[0], 
                 $.extend( 
                   target_#{editor_id.gsub(/-/,'')}, 
                   #{options.to_json}, 
                   { extraKeys: {"Ctrl-Q": function(cm){ cm.foldCode(cm.getCursor()); }},
                    foldGutter: true, 
                    gutters: ['CodeMirror-linenumbers', 'CodeMirror-foldgutter'] }
            ))});
            EOF
      javascript_tag(js) + 
      if autoheight
      javascript_tag("$('document').ready( function(){$('##{editor_id}').siblings('.CodeMirror').css({'height' : 'auto', 'border' : '1px solid #eee'})});")
      end.to_s.html_safe
    end #def
    
    ######################################################################################
    # returns dead_button (unsupported code with deactivated button) html for use in macros
    ######################################################################################
    def dead_code_button( text, message, options={} )
      msg = case message
      when Symbol
        ::I18n.t(message, options)
      when String
        message
      end
      (options[:code] ? text : content_tag(:pre, text)) +
      content_tag(:pre) do
        submit_tag(l(:button_try), :disabled => true) + " " + content_tag(:span, msg) 
      end #content_tag
    end #def
          
    ######################################################################################
    # returns dead_button (unsupported code) html for use in macros
    ######################################################################################
    def unsupported_code_button( text, message, options={} )
      msg = case message
      when Symbol
        ::I18n.t(message, options)
      when String
        message
      end
      (options[:code] ? text : content_tag(:pre, text)) +
      content_tag(:pre) do
        content_tag(:span, msg) 
      end #content_tag
    end #def
          
    ######################################################################################
    # code result pane
    ######################################################################################
    def result_pane(tag_id)
      content_tag(:div, :id => "#{tag_id}-x", :style => "display:none;") do 
        content_tag(:p, "", :class => "contextual") do
          content_tag(:span, "&nbsp;".html_safe, :class => "icon icon-close", :onclick => "$('##{tag_id}-x').hide();")
        end +
        content_tag(:div, "", :id => "#{tag_id}")
      end
    end #def
    
    ######################################################################################
    # add form to event listener, that shows ajax indicator after confirm dialog
    ######################################################################################
    def indicator_on_confirm_click( form_id )
      content_for :header_tags do
        javascript_tag( "$( document ).ready(function() { indicatorOnConfirmClick('#{form_id}')});" )
      end
    end #def
    
    ######################################################################################
    # catch error status with ajax
    ######################################################################################
    def error_catcher
      javascript_tag(
        <<-EOF.strip_heredoc
          $(document).on("ajax:error", function(event) {
            var detail = event.detail;
            var data = detail[0], status = detail[1],  xhr = detail[2];
            $("#content").prepend(xhr.responseText);
          });
        EOF
      )
    end  #def
  end #module
end #module
