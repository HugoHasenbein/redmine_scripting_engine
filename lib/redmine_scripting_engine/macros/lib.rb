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
    
        desc "Shows libs in library hierarchy \n" +
             "Added by RedmineScriptingEngine plugin.\n" +
             "Only works on a wiki page.\n" +
             "parameters: \n" +
             "lang:       code type, i.e ruby, shell, python, etc.\n" +
             "numbering=: optional parameter: prints code with line numbers\n" +
             "Example:\n" +
             "{{lib(ruby, numbering=1)}}"
             
        macro :lib do |obj, args|
        
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
          return unsupported_code_button( code, 
            :notice_only_wikipage_supported, 
            :language => language,
            :code => true ) unless obj.is_a?(WikiContent)
            
          ################################################################################
          # 3. get arguments
          ################################################################################
          args, options = extract_macro_options(args, :numbering)
          
          ################################################################################
          # 4. filter, set/unset options
          ################################################################################
          type          = args[0].to_s; language = RSE_LANGUAGES[type]
          numbering     = boolean_string( options[:numbering])
          
          ################################################################################
          # 5. language supported?
          ################################################################################
          supported     = Redmine::SyntaxHighlighting.language_supported?(language)
          return unsupported_code_button( "", 
            :notice_syntax_not_supported, 
            :language => language) unless supported
          
          ################################################################################
          # get libs in hierarchy
          ################################################################################
          ancestor_libs  = RedmineScriptingEngine::Lib::RseWikiScript.
            wikiscript_libs(project, language)
            
          ################################################################################
          # 6. create code html for each ancestors lib
          ################################################################################
          line_num = 1
          ancestor_libs.map do |ancestor,lib|
            lib_tag = 
            content_tag(:p, ancestor.name) +
            format_code(lib, 
              :language => language, 
              :numbering => numbering, 
              :line_num => line_num,
              :preclass => type
            )
            line_num += lib.split(/\n/).length
            lib_tag
          end.join("\n").html_safe
        end #macro
        
    end #register
    
  end #module
end #module
