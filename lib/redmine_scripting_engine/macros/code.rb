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
    
        desc "Formats the text content as code \n" +
             "Added by RedmineScriptingEngine plugin.\n" +
             "parameters: \n" +
             "lang:       code type, i.e ruby, shell, python, etc.\n" +
             "numbering=: optional parameter: prints code with line numbers\n" +
             "liblines=:  optional parameter: start numbering considering number of lib code lines (only on WikiScript pages)" +
             "text:       code to format\n" +
             "Example:\n" +
             "{{code(ruby) \n" +
             "Hello World" +
             "}}"
             
        macro :code do |obj, args, text|
        
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
          # noop
          
          ################################################################################
          # 2. load helpers
          ################################################################################
          unless self.class.included_modules.include?( RedmineScriptingEngine::MacrosHelper )
          self.class.class_eval{ include RedmineScriptingEngine::MacrosHelper }
          end
          
          ################################################################################
          # 3. get arguments
          ################################################################################
          args, options = extract_macro_options(args, :numbering,:liblines)
          
          ################################################################################
          # 4. filter, set/unset options
          ################################################################################
          type          = args[0].to_s; language = RSE_LANGUAGES[type]
          numbering     = boolean_string( options[:numbering])
          liblines      = boolean_string( options[:liblines])
          
          ################################################################################
          # count total lines in all ancestor libs
          ################################################################################
          if liblines && obj.is_a?(WikiContent)
            liblines = RedmineScriptingEngine::Lib::RseWikiScript.
              wikiscript_libs(project, language).
              map{|ancestor,lib| lib }.
              join("\n").split(/\n/).length 
          else
            liblines = 0
          end
            
          ################################################################################
          # 5. language supported?
          ################################################################################
          supported = Redmine::SyntaxHighlighting.language_supported?(language)
          return unsupported_code_button( text, 
            :notice_syntax_not_supported, 
            :language => language) unless supported
          
          ################################################################################
          # 6. create code html
          ################################################################################
          format_code(text, 
            :language => language, 
            :numbering => numbering, 
            :line_num => liblines + 1,
            :preclass => type)
        end #macro
        
    end #register
    
  end #module
end #module
