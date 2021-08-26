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

# core patches
require "redmine_scripting_engine/patches/abstract_reflection_patch"

# patches
require "redmine_scripting_engine/patches/application_helper_patch"
require "redmine_scripting_engine/patches/custom_field_patch"
require "redmine_scripting_engine/patches/custom_field_value_patch"
require "redmine_scripting_engine/patches/customizable_patch"
require "redmine_scripting_engine/patches/field_format_patch"
require "redmine_scripting_engine/patches/journal_patch"
require "redmine_scripting_engine/patches/member_patch"
require "redmine_scripting_engine/patches/member_role_patch"
require "redmine_scripting_engine/patches/repository_patch"
require "redmine_scripting_engine/patches/repository_patch"
require "redmine_scripting_engine/patches/role_patch"
require "redmine_scripting_engine/patches/setting_patch"
require "redmine_scripting_engine/patches/settings_helper_patch"
require "redmine_scripting_engine/patches/wiki_content_patch"
require "redmine_scripting_engine/patches/wiki_page_patch"

# hooks
require "redmine_scripting_engine/hooks/context_menu_hook"
require "redmine_scripting_engine/hooks/contextual_hook"
require "redmine_scripting_engine/hooks/custom_field_hook"
require "redmine_scripting_engine/hooks/global_sidebar_hook"
require "redmine_scripting_engine/hooks/header_hook"
require "redmine_scripting_engine/hooks/wiki_hook"

# libs
require "redmine_scripting_engine/lib/rse_utils"
require "redmine_scripting_engine/lib/digger"
require "redmine_scripting_engine/lib/exceptions"
require "redmine_scripting_engine/lib/macros_helper"
require "redmine_scripting_engine/lib/redmine_script"
require "redmine_scripting_engine/lib/rse_class_factory"
require "redmine_scripting_engine/lib/rse_file"
require "redmine_scripting_engine/lib/rse_text"
require "redmine_scripting_engine/lib/rse_wiki_porter"
require "redmine_scripting_engine/lib/rse_wiki_scan"
require "redmine_scripting_engine/lib/rse_wiki_script"

# macros
require "redmine_scripting_engine/macros/code"
require "redmine_scripting_engine/macros/fiddle"
require "redmine_scripting_engine/macros/script"
require "redmine_scripting_engine/macros/snippet"
require "redmine_scripting_engine/macros/try"
require "redmine_scripting_engine/macros/lib"

require "redmine_scripting_engine/macros/tags/box"
require "redmine_scripting_engine/macros/tags/div"
require "redmine_scripting_engine/macros/tags/input"
require "redmine_scripting_engine/macros/tags/select"
require "redmine_scripting_engine/macros/tags/wiki"
require "redmine_scripting_engine/macros/tags/project"
require "redmine_scripting_engine/macros/tags/yes"
require "redmine_scripting_engine/macros/tags/no"

