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
  module Patches 
    module MemberPatch
      def self.included(base)
        base.class_eval do
          
          after_save    :invalidate_wikiscripts_key # cache for finding wikiscripts
          after_destroy :invalidate_wikiscripts_key # cache for finding wikiscripts
          
          ################################################################################
          # a change of project members may lead to a change in visibility of scripts
          ################################################################################
          def invalidate_wikiscripts_key
            RedmineScriptingEngine::Lib::RseWikiScript.invalidate_wikiscripts_key
          end #def
          private :invalidate_wikiscripts_key
          
        end #base
      end #self
    end #module
  end #module
end #module

unless Member.included_modules.include?(RedmineScriptingEngine::Patches::MemberPatch)
  Member.send(:include, RedmineScriptingEngine::Patches::MemberPatch)
end


