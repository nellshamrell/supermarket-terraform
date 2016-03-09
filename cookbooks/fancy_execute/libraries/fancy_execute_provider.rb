#
# Author:: Irving Popovetsky (<irving@chef.io)
# Copyright:: Copyright (c) 2014 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/log'
require 'chef/provider'

class Chef
  class Provider
    class FancyExecute < Chef::Provider::Execute

      # this code will only work with Chef 12.4+
      provides :execute, override: true

      # force this to on if not set
      Chef::Config[:live_stream] ||= true

      def opts
        opts = {}
        opts[:timeout]     = timeout
        opts[:returns]     = returns if returns
        opts[:environment] = environment if environment
        opts[:user]        = user if user
        opts[:group]       = group if group
        opts[:cwd]         = cwd if cwd
        opts[:umask]       = umask if umask
        opts[:log_level]   = :info
        opts[:log_tag]     = new_resource.to_s
        opts[:live_stream] = STDOUT if live_stream?
        opts
      end

      def live_stream?
        # never live_stream if sensitive
        return false if sensitive?
        # check if Chef::Config[:live_stream] was overridden to true, otherwise use default logic
        if Chef::Config[:live_stream] == true || (STDOUT.tty? && !Chef::Config[:daemon] && Chef::Log.info?)
          true
        else
          false
        end
      end

    end
  end
end

# Set FancyExecute as the default provider for :execute on Linux platforms
%w(debian ubuntu fedora redhat centos).each do |platform|
  Chef::Platform.set plaform: platform.to_sym, resource: :execute, provider: Chef::Provider::FancyExecute
end
