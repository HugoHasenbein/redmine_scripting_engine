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

class Inappropriate < StandardError
  attr_reader :message
  def initialize(msg= ::I18n.t(:notice_inapproriate_type) )
    super
    @message = msg
  end
end

class InvalidFile < StandardError
  attr_reader :message
  def initialize(msg= ::I18n.t(:notice_invalid_file) )
    super
    @message = msg
  end
end


