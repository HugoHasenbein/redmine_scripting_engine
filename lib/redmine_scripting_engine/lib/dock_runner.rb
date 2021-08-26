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

# Rails basic support
require 'active_support/all'

# time support
require 'active_support/time_with_zone'
require 'active_support/core_ext/time/zones'

# query support
require 'active_support/core_ext/object/to_query'

# rails action view
require "action_view"

# json support
require "active_support/json"

# HTTP support
require 'net/http'

# Open3 support
require 'open3'

# Redmine API Helper
require 'redmine_api_helper'

# HashBase
require 'hash_base'


##
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
class DockRunner

  ########################################################################################
  #
  # includes
  #
  ########################################################################################
  include ::ActionView::Helpers::DateHelper
  include ::ActionView::Helpers::TagHelper
  include ::ActionView::Context
  
  include ::RedmineAPIHelper::Helpers
  include ::ODFWriter::ODFHelper
  
  ########################################################################################
  #
  # DockRuner / dock_runner.rb
  #
  # is copied to the docker evironment and supplies all necessary
  # includes and basic functions to script redmine
  #
  ########################################################################################
  attr_accessor :index
  attr_reader   :code
  
  def initialize(code, args={})
    @code  = code
    @index = 0
    args.each do |name, value|
      singleton_klass = class << self; self; end
      singleton_klass.class_eval { attr_reader name }
      instance_variable_set "@#{name}", value
    end
  end
  
  def run
    begin
    
    # write attachments to readable file
    @atts.to_h.each do |fname, content64|
    att_dir = File.join("/home", "sandbox", "atts")
    FileUtils.mkdir_p(att_dir)
    att_path = File.join(att_dir, fname)
    File.open(att_path, 'wb') { |file| file.write(Base64.decode64(content64)) }
    File.chmod(0644, att_path)
    end
    
    case @args.type.to_s.downcase
      when "ruby"
        run_ruby
      when "shell"
        run_shell
      when "c"
        run_any("tcc", "-run")
      when "python"
        run_any( "python" )
      when "perl"
        run_any( "perl" )
      else
        @code
      end
    rescue Exception => e
      ([e.message] + e.backtrace).join("\n")
    end
  end
    
  ########################################################################################
  # private 
  ########################################################################################
  private
  
  ########################################################################################
  # run_ruby
  ########################################################################################
  def run_ruby
    eval @code
  end #def
  
  ########################################################################################
  # run_shell
  ########################################################################################
  def run_shell
  
    # write script to executable file
    exe_path  = File.join("/home", "sandbox", "script")
    File.open(exe_path, 'w') { |file| file.write(@code) }
    File.chmod(0755, exe_path) 
    
    # write args to readable file
    args_path = File.join("/home", "sandbox", "args.json")
    File.open(args_path, 'w') { |file| file.write(deserialize(@args).to_json) }
    File.chmod(0644, args_path) 
    
    stdout_str, stderr_str, status = [nil,nil,nil]
    Open3.popen3(exe_path, args_path) {|stdin, stdout, stderr, wait_thr|
      pid = wait_thr.pid         # pid of the started process.
      stdin.write deserialize(@args.params).to_json # url parameters are piped to shell
      stdin.close                # we're done
      stdout_str = stdout.read   # read stdout to string. note that this will block until the command is done!
      stderr_str = stderr.read   # read stderr to string
      status = wait_thr.value    # will block until the command finishes; returns status that responds to .success? etc
    }
    stdout_str.to_s + stderr_str.to_s
  end #def
  
  ########################################################################################
  # run_shell (this function is suited to add other interpreters, possibly php or java)
  ########################################################################################
  def run_any( interpreter, args=nil )
    # write script to file
    exe_path  = File.join("/home", "sandbox", "script")
    File.open(exe_path, 'w') { |file| file.write(@code) }
    File.chmod(0644, exe_path) 
    
    # write args to readable file
    args_path = File.join("/home", "sandbox", "args.json")
    File.open(args_path, 'w') { |file| file.write(deserialize(@args).to_json) }
    File.chmod(0644, args_path) 
    
    stdout_str, stderr_str, status = [nil,nil,nil]
    Open3.popen3(*[interpreter, args, exe_path, args_path].compact) {|stdin, stdout, stderr, wait_thr|
      pid = wait_thr.pid         # pid of the started process.
      stdin.write deserialize(@args.params).to_json # url parameters are piped to interpreter
      stdin.close                # we're done
      stdout_str = stdout.read   # read stdout to string. note that this will block until the command is done!
      stderr_str = stderr.read   # read stderr to string
      status = wait_thr.value    # will block until the command finishes; returns status that responds to .success? etc
    }
    stdout_str.to_s + stderr_str.to_s
  end #def
  
end #class