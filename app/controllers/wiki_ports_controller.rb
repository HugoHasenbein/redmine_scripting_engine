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

class WikiPortsController < ApplicationController

  ########################################################################################
  #
  # global controller settings
  #
  ########################################################################################
  menu_item(:wiki, :only => :index)
  
  ########################################################################################
  #
  # includes
  #
  ########################################################################################
  include RedmineScriptingEngine::Lib
  include ActionController::Live
  helper :wiki
  include WikiHelper
  helper :wiki_ports
  include WikiPortsHelper
  
  ########################################################################################
  #
  # rescuers
  #
  ########################################################################################
  rescue_from ::Unauthorized, :with => :deny_access
  
  ########################################################################################
  #
  # callbacks
  #
  ########################################################################################
  before_action :require_admin,                 :only => [:import, :export, :index]
  before_action :find_project_by_project_id,    :only => [:import, :export, :index]
  before_action :find_optional_page,            :only => [:import, :export]
  before_action :find_optional_page_by_page_id, :only => [:index]
  
  ########################################################################################
  #
  # controller functions
  #
  ########################################################################################
  
  ########################################################################################
  # shows import /export dialog
  ########################################################################################
  def index
  end #def
  
  ########################################################################################
  # exports wikiscripts to zip file
  ########################################################################################
  def export
  
    if RseWikiPorter.preestimate( @project, @page.try(:id) )
  
      history = (%w(1 true yes ok).include? params[:history])
      
      begin
      
        send_file_headers!(
          :type        => "application/zip",
          :disposition => "attachment",
          :filename    => "Wikiscripts.zip"
        )
        response.headers["Last-Modified"]     = Time.now.httpdate.to_s
        response.headers["X-Accel-Buffering"] = "no"
        
        RseWikiPorter.export(@project, @page, history) do |chunk|
          response.stream.write(chunk)
        end
        
      ensure
        response.stream.close
      end
    else
      flash[:error] = "oops, no wikiscripts"
      redirect_to :back
    end
  end #def
  
  ########################################################################################
  # exports wikiscripts from zip file
  ########################################################################################
  def import
    
    if params[:file].is_a?(ActionDispatch::Http::UploadedFile)
      Dir.mktmpdir do |tdir|
        Dir.mktmpdir do |twikidir|
          tmpfile = File.join(tdir, "import.zip")
          
          # save file into temporary directory, rely on server to limit length of file
          File.open(tmpfile, "wb"){|f| f.write params[:file].read }
          
          # check, if uploaded file is a zip file
          if valid_zip?( tmpfile )
          
          # expand file
            extract_zip(tmpfile, twikidir)
            
          # import file
            RseWikiPorter.import(@project, :dir => twikidir, :parent => @page )
            flash[:notice] = l(:notice_file_imported)
            redirect_to :back
          else
          # feedback error
            flash[:error] = l(:notice_invalid_file)
            redirect_to :back
          end #if
        end #dir
      end #dir
    else
      flash[:error] = l(:notice_invalid_file)
      redirect_to :back
    end
    
  rescue Exception => e
    Rails.logger.info ([e.message] + e.backtrace).join("\n")
    flash[:error] = e.message
    redirect_to :back
  end #def
  
  ########################################################################################
  #
  # private functions
  #
  ########################################################################################
  private
  
  def find_optional_page
    if params[:id].present?
      @page = WikiPage.find(params[:id].to_i)
      raise ActiveRecord::RecordNotFound unless @project == @page.project
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end #def
  
  def find_optional_page_by_page_id
    if params[:page_id].present?
      @page = WikiPage.find(params[:page_id].to_i)
      raise ActiveRecord::RecordNotFound unless @project == @page.project
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end #def
  
  # checks, if file is a valid zip file
  def valid_zip?(file)
    zip = Zip::File.open(file)
    true
  rescue StandardError
    false
  ensure
    zip.close if zip
  end #def
  
  # extracts zip file to folder dir
  def extract_zip(file, dir)
    Zip::File.open(file) do |zip_file|
      zip_file.each do |entry|
        sanpath = RseFile.sanitize_subdir( File.join(dir, entry.name), dir)
        raise InvalidFile unless sanpath
        case entry.ftype
        when :file 
          FileUtils.mkdir_p( File.dirname(sanpath)) 
        when :directory
          FileUtils.mkdir_p( sanpath) 
        end
        entry.restore_times = true
        entry.extract(sanpath) 
      end #zip_file
    end #Zip::File
  end #def
  
end #class