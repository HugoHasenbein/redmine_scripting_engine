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

Redmine::Plugin.register :redmine_scripting_engine do
  name 'Redmine Scripting Engine'
  author 'Stephan Wenzel'
  description 'Execute untrusted scripts'
  version '0.0.1'
  url 'https://github.com/HugoHasenbein/redmine_scripting_engine'
  author_url 'https://github.com/HugoHasenbein/redmine_scripting_engine'
  
  #---------------------------------------------------------------------------------------
  # Default values
  #---------------------------------------------------------------------------------------
  settings :default  => {'wikiscripts_root'            => 'Wikiscripts',
                         'forbidden_attributes_filter' => ["login", "password"],
                         'issues_context_menu'         => '1',
                         'issue_assocications'         => ['all'],
                         'registered_classes'          => {'user'         => {'associations' => ['all'], 'attributes_filter' => ''},
                                                           'issue'        => {'associations' => ['all'], 'attributes_filter' => ''},
                                                           'journal'      => {'associations' => ['all'], 'attributes_filter' => ''},
                                                           'time_entry'   => {'associations' => ['all'], 'attributes_filter' => ''},
                                                           'wiki_page'    => {'associations' => ['all'], 'attributes_filter' => ''},
                                                           'wiki_content' => {'associations' => ['all'], 'attributes_filter' => ''},
                                                           'document'     => {'associations' => ['all'], 'attributes_filter' => ''},
                                                           'project'      => {'associations' => ["parent", "memberships", "members",
                                                                              "enabled_modules", "trackers", "default_version", 
                                                                              "default_assigned_to", "issue_categories", "repository", 
                                                                              "repositories", "changesets", "wiki", "issue_custom_fields", 
                                                                              "custom_values"], 'attributes_filter' => ''}},
                         'register_classes'            => '',
                         'advanced_mode'               => '',
                         'reset'                       => ''
                         },
           :presets =>  {'wikiexts'                    => {'textile'  => 'textile', 
                                                           'markdown' => 'md',
                                                           ''         => 'txt'
                                                           }},
           :partial  =>  'plugin_settings/redmine_scripting_engine/settings'
           
  #---------------------------------------------------------------------------------------
  # Permissions
  #---------------------------------------------------------------------------------------
  project_module :redmine_scripting_engine do
    # writing WikiScripts is controlled by wiki_page.locked
    # only locked scripts are considered by Redmine Scripting Engine
    # who has the right to lock and unlock pages is trustworty
    # to write scripts
    permission :view_scripts,       :scripts => [:index]
    permission :run_scripts,        :scripts => [:index, :run]      # run green scripts from context menu
    permission :run_red_scripts,    :scripts => [:index, :run]      # run red   scripts from context menu
    permission :run_html_scripts,   :scripts => [:index, :run]      # run html  scripts from context menu
    permission :run_mime_scripts,   :scripts => [:index, :run]      # run mime scripts from context menu
    permission :run_tries,          :scripts => [:index, :run]      # run tries on wikipage
                                    
    permission :run_snippets,       :scripts => [:snippet]          # run snippet anywhere
    permission :run_fiddles,        :scripts => [:snippet, :fiddle] # run fiddle anywhere
    permission :run_html_fiddles,   :scripts => [:snippet, :fiddle] # run html fiddle anywhere
    permission :run_mime_fiddles,   :scripts => [:snippet, :fiddle] # run mime fiddle anywhere
    
    permission :write_snippets,     :scripts => [:snippet]          # run snippet anywhere
    permission :write_fiddles,      :scripts => [:snippet, :fiddle] # run fiddle anywhere
    permission :write_html_fiddles, :scripts => [:snippet, :fiddle] # run html fiddle anywhere
    permission :write_mime_fiddles, :scripts => [:snippet, :fiddle] # run mime fiddle anywhere

  end
  
end

  #---------------------------------------------------------------------------------------
  # CONSTANTS: do not add type, unless dock_runner.rb knows what to do with newly added type
  #---------------------------------------------------------------------------------------
  RSE_SUPPORTED_TYPES = ["ruby", "api", "shell", "c", "python", "perl"].freeze
  
  RSE_LIBRARY_SECTION = { "ruby"    => "LibRuby", 
                          "api"     => "LibAPI",
                          "shell"   => "Profile", 
                          "c"       => "Libc", 
                          "perl"    => "LibPerl", 
                          "python"  => "LibPython"}.freeze
                          
  RSE_LANGUAGES       = { "ruby"    => "ruby",
                          "api"     => "ruby",
                          "shell"   => "shell", 
                          "c"       => "c", 
                          "perl"    => "perl", 
                          "python"  => "python"}.freeze
                          
  RSE_CODEMIRROR_VERSION = "codemirror-5.62.2".freeze
                          
  RSE_CODEMIRROR_MODES = {"ruby"    => "ruby",
                          "api"     => "ruby",
                          "shell"   => "shell", 
                          "c"       => "clike", 
                          "perl"    => "perl", 
                          "python"  => "python"}.freeze
                          
  RSE_CODEMIRROR_MIMES = {"ruby"    => "text/x-ruby", 
                          "api"     => "text/x-ruby", 
                          "shell"   => "text/x-sh", 
                          "c"       => "text/x-csrc", 
                          "perl"    => "text/x-perl", 
                          "python"  => "text/x-python"}.freeze
                          
  RSE_CODEMIRROR_EXTS  = {"ruby"    => ".rb", 
                          "api"     => ".rb", 
                          "shell"   => ".sh", 
                          "c"       => ".c", 
                          "perl"    => ".pl", 
                          "python"  => ".py"}.freeze
                          
  RSE_RUN_COMMANDS     = {"ruby"    =>                    "ruby #{File.join("src", "script.rb")} #{File.join("src", "script.args")}",
                          "api"     => "bundle exec ruby run.rb #{File.join("src", "script.rb")} #{File.join("src", "script.args")}",
                          "shell"   =>                      "sh #{File.join("src", "script.sh")} #{File.join("src", "script.args")}",
                          "c"       =>                "tcc -run #{File.join("src", "script.c") } #{File.join("src", "script.args")}",
                          "perl"    =>                    "perl #{File.join("src", "script.pl")} #{File.join("src", "script.args")}",
                          "python"  =>                  "python #{File.join("src", "script.py")} #{File.join("src", "script.args")}",
                           nil      =>                    "echo #{File.join("src", "script.*")}"}.freeze
                          
  RSE_DOCKER_CONFIG    = File.join(__dir__, "config", "docker.yml").freeze
  
Rails.application.config.after_initialize do

  #---------------------------------------------------------------------------------------
  # Add permissions
  #---------------------------------------------------------------------------------------
  
  # push additional wiki export permissions
  Redmine::AccessControl.permission(:export_wiki_pages ).actions.push("wiki_ports/export")
  Redmine::AccessControl.permission(:edit_wiki_pages   ).actions.push("wiki_ports/import")
  
end
