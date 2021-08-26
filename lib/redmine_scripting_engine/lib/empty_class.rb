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

class EmptyClass

  attr_accessor :id, :project, :created_on, :updated_on
  
  def initialize(options={})
    @id         = options[:id]
    @project    = options[:project]
    @created_on = DateTime.now()
    @updated_on = @created_on
  end #def
  
  ########################################################################################
  # visible?
  ########################################################################################
  def visible?
    true
  end #def
  
  ########################################################################################
  # attributes
  ########################################################################################
  def attributes
    {:id => id, :project => project, :created_on => created_on, :updated_on => updated_on}
  end #def
  
  ########################################################################################
  # to_s
  ########################################################################################
  def to_s
    [self.class.name, id].compact.join(":")
  end #def
  
  ########################################################################################
  # self.reflect_on_all_associations
  ########################################################################################
  def self.reflect_on_all_associations
    []
  end #def
  
  ########################################################################################
  # self.find
  ########################################################################################
  def self.find(args)
    return new(:id => args) unless args.is_a?(Array)
    Array(args).map{|arg| new(:id => arg)}
  end #def
  
end #class



