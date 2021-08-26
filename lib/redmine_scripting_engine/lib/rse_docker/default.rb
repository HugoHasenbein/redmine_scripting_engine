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
    module RseDocker
      module Default
      
        VALUES = {
          ################################################################################
          # default values for creating docker environment
          ################################################################################
          'create' => {
            'CpuShares'        => 1,
            'Memory'           => 52428800,
            'AttachStdin'      => false,
            'AttachStdout'     => true,
            'AttachStderr'     => true, 
            'Tty'              => false, #if true then stderr is redirected to stdout
            'OpenStdin'        => false,
            'StdinOnce'        => false,
            'Cmd'              => [],
            'Image'            => "redmine_scripting_engine:latest",
            'Volumes'          => {
                "/home/sandbox/src" => {}
            },
           'NetworkDisabled'  => true,
          },
          
          ################################################################################
          # default values for providing a docker certificate 
          ################################################################################
          'cert' => {
            'private_key_path' => 'code_cert/key.pem',
            'certificate_path' => 'code_cert/cert.pem',
            'ssl_verify_peer'  => false
          },
          
          ################################################################################
          # default values for starting a docker container 
          ################################################################################
          'start' => { },
          
          ################################################################################
          # default values for redmine scripting engine
          ################################################################################
          'rse' => {
            'dockersourcedir'   => "/home/sandbox/src",
            'dockerattsdir'     => "/home/sandbox/atts",
            'servermountdirs'   => File.join(Rails.root, "tmp", "docker_dirs"),
            'timeout'           => 15,
            'keepcontainer'     => false,
            'keepmountdir'      => false,
            'unprotectedmode'   => false
          }
        }
      end #module
    end #module
  end #module
end #module


