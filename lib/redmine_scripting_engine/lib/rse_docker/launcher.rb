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
      class Launcher
      
        class_attribute :configuration
        
        class << self
        
          ################################################################################
          #
          # includes
          #
          ################################################################################
          include RedmineScriptingEngine::Lib::RseUtils
          
          ################################################################################
          # runs code
          ################################################################################
          def run(conf=config, **options)
            if conf.dig('rse', 'unprotectedmode')
              run_unprotected(conf, **options)
            else
              run_in_sandbox(conf, **options)
            end
          end
          
          ################################################################################
          # runs code with with overridden configuration parameters
          ################################################################################
          def run_with_options(config_override={}, **options)
            run(config.deep_merge(config_override), **options)
          end #def
          
          ################################################################################
          # run_in_sandbox
          ################################################################################
          def run_in_sandbox(conf=config, **options)
          
            script       = options[:script].to_s      # script to run
            type         = options[:type].to_s        # script type to run
            attachments  = options[:attachments].to_a # array of paths to copy to docker
            arguments    = options[:args].to_h        # arguments hash
            
            # 1. create container, 'type' creates appropriate command / entrypoint
            container = create_container(conf, :type => type)
            
            # 2. create container, use container name as directory name
            dir = create_mount_dir(conf, container.stats['name'])
            
            # 3. dump script to file, which can be read in docker
            dump_script(script, type, dir, conf)
            
            # 4. dump arguments
            dump_args(dir, conf, :type => type, :args => arguments)
            
            # 4. copy attachments to 'atts' directory
            copy_attachments(attachments, dir, conf)
            
            # 5. start container and return output
            start_container(container, dir, conf, :type => type)
            
          ensure
          
            # 6. start container and return output
            remove_container(container, conf)
            
            # 7. start container and return output
            remove_mount_dir(dir, conf)
          end #def
          
          ################################################################################
          # run_unprotected
          ################################################################################
          def run_unprotected(conf=config, **options)
          
          end #def
          
          ################################################################################
          # creates a container
          ################################################################################
          def create_container(conf=config, **options)
            cmd = RSE_RUN_COMMANDS[options[:type]] || RSE_RUN_COMMANDS[nil]
            Docker::Container.create( create_params(cmd, conf) )
          end #def
          
          ################################################################################
          # starts container with Timeout; returns stdout, stderr, result_code
          ################################################################################
          def start_container(container, dir, conf=config, **options)
          
            timeout = conf.to_h.dig('rse', 'timeout').to_i
            
            result = Timeout.timeout(timeout) do
              # start container asynchronously
              # wait for a max of timeout to finish and to capture stdout/stderr log
              container.start( start_params(dir, conf) ).wait(timeout)
              # attach is not suitable here as it will attach live and return whatever
              # is returned in a instance after start.
              # attach(stream: false, stdin: nil, stdout: true, stderr: true, logs: true, tty: false) 
            end
            
            container_response(container, result, conf, :type => options[:type], :dir => dir)
            
          rescue Timeout::Error => e
            error_response(e)
          end
          
          ################################################################################
          # removes a container
          ################################################################################
          def remove_container(container, conf=config)
            container.delete( force: true ) if container && !conf.to_h.dig('rse', 'keepcontainer')
          end
          
          ################################################################################
          # creates mount_dir, which is mounted by docker
          ################################################################################
          def create_mount_dir(conf=config, seed=nil)
            dir = File.join(conf.to_h.dig('rse', 'servermountdirs'), seed || SecureRandom.uuid)
            FileUtils.mkdir_p dir; dir
          end #def
          
          ################################################################################
          # deletes mount_dir, which was mounted by docker
          ################################################################################
          def remove_mount_dir(dir, conf=config)
            FileUtils.rm_rf dir if dir.present? && File.exist?(dir) && !conf.to_h.dig('rse', 'keepmountdir')
          end
          
          ################################################################################
          # dumps script to docker mount dir
          ################################################################################
          def dump_script(script, type, dir, conf=config)
            fname = ['script', RSE_CODEMIRROR_EXTS[type]].compact.join
            fpath = File.join(dir, fname)
            # TODO: on Windows systems the bits of chown may be different
            # here we make the script world R/W to make the sandbox user
            # of the docker able to read the file
            File.open(fpath, "w"){|f| f.write(script)}
            FileUtils.chmod(0666, fpath)
          end #def
          
          ################################################################################
          # dump_args
          ################################################################################
          def dump_args(dir, conf=config, **options)
            fname = "script.args"
            fpath = File.join(dir, fname)
            args  = options[:args]  # arguments hash
            type  = options[:type]  # script type, of which 'api' and 'ruby' is special
            case type
            when 'api'
              File.open(fpath, "wb"){|f| f.write(Marshal.dump(serialize(args)))}
            else
              File.open(fpath, "w"){|f| f.write(args.to_json)}
            end
            FileUtils.chmod(0666, fpath)
          end #def
          
          ################################################################################
          # copies attachments to docker mount dir
          ################################################################################
          def copy_attachments( atts, dir, conf=config)
            attspath = File.join(dir, 'atts'); FileUtils.mkdir_p(attspath)
            atts.each do |path, fname|
              destpath = File.join(attspath, fname)
              FileUtils.cp(path, destpath); FileUtils.chmod_R( 0666, destpath );
            end
            
          end #def
          
          ################################################################################
          # creates create params to create docker image
          ################################################################################
          def create_params(cmd, conf=config)
            conf['create'].to_h.merge('Cmd' => cmd.split(/ /))
          end #def
          
          ################################################################################
          # creates start params to start docker image
          ################################################################################
          def start_params(dir, conf=config, **options)
            conf['start'].to_h.merge(
              'Binds' => ["#{dir}:#{conf.to_h.dig('rse', 'dockersourcedir')}"]
            )
          end #def
          
          ################################################################################
          # container_response with docker status 
          ################################################################################
          def container_response(container, result, conf=config, **options)
            case options[:type]
            when 'api'
              error  = sanitize_logs(container.logs(stderr: true), conf)
              serialize(
                output: error.blank? && File.open(File.join(options[:dir], "script.args"), "rb"){|f| Marshal.load(f.read)},
                error:  {message:   error, 
                         backtrace: [] },
                status: error.present? ? 5 : result['StatusCode'] # bundle does not pass on result codes of "exec …"
              )
            else
              serialize(
                output: sanitize_logs(container.logs(stdout: true), conf),
                error:  {message:   sanitize_logs(container.logs(stderr: true), conf), 
                         backtrace: [] },
                status: result['StatusCode']
              )
            end
          end #def
          
          ################################################################################
          # sanitize_log (if no tty is attached, then logs have 8 Bytes prepended)
          ################################################################################
          def sanitize_logs(logs, conf=config)
            logs.split(/\n/).map{|line| line[8..-1] }.join("\n") unless conf.dig('create', 'Tty')
          end #def
          
          ################################################################################
          # returns true if Docker is available
          ################################################################################
          def available?
            begin Docker.version; true; rescue Exception => e; false; end
          end #def
          
          ################################################################################
          # loads configuration data, call once at startup
          ################################################################################
          def config
            self.configuration ||= RseDocker::Config.new.load
          end #def
          
        end #self
      end #class
    end #module
  end #module
end #module