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

RedmineApp::Application.routes.draw do

  resources :projects, :only => [] do
  
    # wiki_ports controller executes scripts
    resources :wiki_ports, :only => [:index] do
      collection do
        post 'import'
        get  'export'
      end
      member do
        post 'import'
        get  'export'
      end
    end
    
    # scripts controller executes scripts
    resources :scripts, :only => [:index] do
      collection do
        post "fiddle"
        post "snippet"
      end
      member do
        get "run"
      end
    end
    
  end
  
  # scripts controller executes scripts
  resources :scripts, :only => [] do
    collection do
      post "fiddle"
      post "snippet"
    end
    member do
      get "run"
    end
  end
  
  # empty_classes controller handles dummy classes
  resources :empty_classes, :format => "json", :except => [:new, :edit]
  
end
