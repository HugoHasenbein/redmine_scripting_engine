##########################################################################################
#
# requires
#
##########################################################################################

# Rails basic support, needed for Marshal and OpenSTruct
require 'active_support/all'

##########################################################################################
#
# define runner class
#
##########################################################################################
class Runner

  # Rails action view
#  require "action_view"
#  include ::ActionView::Helpers::DateHelper
#  include ::ActionView::Helpers::TagHelper
#  include ::ActionView::Context

# Rails timezone support
#  require 'active_support/time_with_zone'
#  require 'active_support/core_ext/time/zones'

  # Redmine API Helper
  require 'redmine_api_helper'
  
  # Goodie: HashBase
  require 'hash_base'
  
  include ::RedmineAPIHelper::Helpers
  include ::ODFWriter::ODFHelper
  
  attr_accessor :script, :args
  
  def initialize(script, args)
    self.script = script
    self.args   = args
  end #def
  
  def run
    eval script
  end
  
  def to_s
    "<Runner:#{self.object_id}>:\"#{script}\""
  end
  
end

##########################################################################################
#
# eventually load data and execute script
#
##########################################################################################
begin
  
  script = File.open(ARGV[0], "r"  ){|f| f.read}
  args   = File.open(ARGV[1], "rb" ){|f| Marshal.load(f.read) } 
  
  result = Runner.new(script,args).run
  
           File.open(ARGV[1], "wb" ){ |f| f.write( Marshal.dump( result )) }
           
rescue Exception => e
  STDERR.puts ([e.message ] + e.backtrace).join("\n")
end