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
      class Config
      
        ##################################################################################
        # loads configuration from configuration yml file
        ##################################################################################
        def load(env = nil)
          return {} unless File.exist?(RSE_DOCKER_CONFIG) && File.readable?(RSE_DOCKER_CONFIG)
          env ||= ENV['RAILS_ENV'] || 'development'
          yaml = begin
            YAML.load_file(RSE_DOCKER_CONFIG) || {}
          rescue Exception => e
            Rails.logger.info "#{RSE_DOCKER_CONFIG}: " + e.message
            {}
          end
          Default::VALUES.deep_merge(yaml[env].to_h)
        end #def
        
      end #class
    end #module
  end #module
end #module