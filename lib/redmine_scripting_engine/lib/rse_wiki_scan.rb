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
  module Lib
    module RseWikiScan
      class << self
      
        # ------------------------------------------------------------------------------ #
        #
        # scan_page_titles, i.e. get the title after h1. (textile) or # (markdown)
        #
        def page_titles( page )
          titles = []
          regex, tregex = get_regex()
          if tregex
            titles = page.content.text.scan(/#{tregex}/m).map do |matched|
              matched.first.gsub(/[\r\n]/, '')
            end
          end
          titles
        end #def
        alias_method :scan_page_titles, :page_titles
        
        # ------------------------------------------------------------------------------ #
        #
        # scan_section_titles, i.e. get the title after hn. (textile, n > 1) or #+ (markdown)
        #                      if title is given, then title presence is returned
        #
        def section_titles( page, title=nil )
          titles = []
          regex, tregex = get_regex()
          if regex
            titles = page.content.text.scan(/#{regex}/m).map do |matched|
              matched.first.gsub(/[\r\n]/, '')
            end
          end
          title ? titles.map{|t| t.match?(/\A#{title}\z/)}.any? : titles
        end #def
        alias_method :scan_section_titles, :section_titles
        
        # ------------------------------------------------------------------------------ #
        #
        # get_section, i.e. get the text below hn. (textile, n > 1) or #+ (markdown)
        #                   first presence is returned
        #
        def section_text( page, section_title )
        
          text = ""
          regex, tregex = get_regex()
          
          if regex
            page.content.text.scan(/#{regex}/m).each.with_index(1) do |matched, i|
              if matched.first.gsub(/[\r\n]/, '') == section_title
                if Redmine::WikiFormatting.supports_section_edit?
                  sectext, hash = Redmine::WikiFormatting.formatter.new(page.content.text).get_section(i)
                  sectext.sub!(/#{regex}/m, '') # exclude heading
                  text << sectext
                end
              end
            end
            
          end
          text
        end #def
        alias_method :get_section, :section_text
        
        # ------------------------------------------------------------------------------ #
        #
        # get_section_words, i.e. get the text below hn. (textile, n > 1) or #+ (markdown)
        #                    as ordered words
        #
        def section_words( page, section_title)
          scan_words( section_text( page, section_title ) )
        end #def
        alias_method :get_section_words, :section_words
        
        # ------------------------------------------------------------------------------ #
        #
        # get_section_code, i.e. get the text below hn. (textile, n > 1) or #+ (markdown)
        #                   as stripped code
        #
        def section_code( page, section_title)
          sanitize_code( section_text( page, section_title ) )
        end #def
        alias_method :get_section_code, :section_code
        
        # ------------------------------------------------------------------------------ #
        #
        # code_type, i.e. get code in textile or markdown
        #                 
        #
        def code_type(page, section_title)
          text = section_text( page, section_title )
          
          # search code in possible macro
          code = text.match(/(?<=\{\{code\()([a-z0-9_#]*),*([^)]*)\)(.*?)(?=\n\}\})/m)
          return code[1] if code
          
          # else search code in formatting
          case Setting.text_formatting
          when "textile"
            doc  = Nokogiri::Slop(text)
            x = doc.at('code').try(:attr, 'class') # fetch first occurence
          when "markdown"
            match = text.match(/(?<=```).*?$/)
            match && match[0]
          end
        end #def
        
        private
        
        # ------------------------------------------------------------------------------ #
        #
        # sanitize_code, i.e. remove   <pre></pre> and <code></code> tags in textile
        #                           or ``` in markdown
        #                           or {{code(name)} \n}
        #
        def sanitize_code(string)
          code = case Setting.text_formatting
          when "textile"
            string.to_s.
            encode(universal_newline: true).
            gsub(/\s*<(?<=<)pre(?= .*?|>).*?>|\s*<(?<=<)\/pre(?= .*?|>).*?>/i, "").
            gsub(/\s*<(?<=<)code(?= .*?|>).*?>|\s*<(?<=<)\/code(?= .*?|>).*?>/i, "").
            gsub(/\{\{code\((.*?)\)(.*?)\n\}\}/m, '\2')
          when "markdown"
            string.to_s.
            encode(universal_newline: true).
            gsub(/^\s*```.*?$/i, "").
            gsub(/\{\{code\((.*?)\)(.*?)\n\}\}/m, '\2')
          else
            string.to_s.
            encode(universal_newline: true)
          end
          code.gsub(/^[\x00\n\v\f\r]*/, "").gsub(/[\x00\n\v\f\r]*?$/, "")
        end #def
        alias_method :sanitize_pre, :sanitize_code
        
        # ------------------------------------------------------------------------------ #
        #
        # sanitize_code, i.e. remove <pre></pre> and <code></code> tags in textile
        #                           or ``` in markdown
        #
        def code(string)
          case Setting.text_formatting
          when "textile"
            string.to_s.
            encode(universal_newline: true).
            scan(/\s*<(?<=<)code(?= .*?|>).*?>|\s*<(?<=<)\/code(?= .*?|>).*?>/i, "")
          when "markdown"
            string.to_s.
            encode(universal_newline: true).
            scan(/^\s*```(.*?)$/i, "").first
          else
            string.to_s.
            encode(universal_newline: true)
          end
        end #def
        
        def scan_words( string )
          string.to_s.squish.split(/;|,|\ /).select(&:present?).uniq.sort
        end #def
        
        # ----------------------------------------------------------------------------------- #
        def get_regex
          regex = nil
          case Setting.text_formatting
          when "textile"
            regex  = '(?:\A|\r?\n\s*\r?\n)h\d+\.[ \t]+(.*?)(?=\r?\n\s*\r?\n|\z)'
            tregex = '(?:\A|\r?\n\s*\r?\n)h1\.[ \t]+(.*?)(?=\r?\n\s*\r?\n|\z)'
          when "markdown"
            regex  = '(?:\A|\r?\n)#+ +(.*?)(?=\r?\n|\z)'
            tregex = '(?:\A|\r?\n)# +(.*?)(?=\r?\n|\z)'
          end
          [regex, tregex]
        end #def
        
      end #class
    end #module
  end #module
end #module
