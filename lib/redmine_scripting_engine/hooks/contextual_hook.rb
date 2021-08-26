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
  module Hooks
    class ContextualHook < Redmine::Hook::ViewListener
    
#       def view_<MODEL_PLURAL>_show_contextual(context={ })
#         context[:controller].send(:render_to_string, {
#           :partial => 'hooks/redmine_scripting_engine/contextual_menu_inserter',
#           :locals => context.merge(:object => context[:<MODEL_SINGULAR>], :class_name => "<MODEL_CLASS_NAME")
#         }) if context[:<MODEL_SINGULAR>].try(:project).try(:module_enabled?, :redmine_scripting_engine) &&
#            Setting["plugin_redmine_scripting_engine"]["<MODEL_PLURAL>_context_menu"]
#       end
    end
  end
end