#
# Copyright:: 2015-2016, Benoit Creau <benoit.creau@chmod666.org>
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

property :file_name, String, name_property: true
property :attributes, Hash
property :stanza, String, desired_state: false

load_current_value do |desired|
  # Check if file exists
  if ::File.exist?(desired.file_name)
    # check if the stanza exists
    # if the stanza does not exists the resource does not exists
    unless ::File.readlines(desired.file_name).grep(/#{desired.stanza}:/)
      Chef::Log.debug("chsec: no stanza found (#{desired.stanza})")
      current_value_does_not_exist!
    end
  else
    raise("chsec: #{desired.file_name} not found")
  end

  # we are loading resource this way
  # a file modified by chsec is like this
  # usw:
  #     shells = /bin/sh,/bin/bsh,/bin/csh,/bin/ksh,/bin/tsh,/bin/ksh93,/usr/bin/sh,/usr/bin/bsh,/usr/bin/csh,/usr/bin/ksh,/usr/bin/tsh,/usr/bin/ksh93,/usr/bin/rksh,/usr/bin/rksh93,/usr/sbin/uucp/uucico,/usr/sbin/sliplogin,/usr/sbin/snappd
  #     maxlogins = 32767
  #     logintimeout = 60
  #     maxroles = 8
  #     auth_type = STD_AUTH

  # Searching for the stanza
  found_stanza = false
  current_attributes = {}
  ::File.open(desired.file_name).each_line do |line|
    if line.chomp == "#{desired.stanza}:"
      Chef::Log.debug("chsec: found stanza (#{desired.stanza})")
      found_stanza = true
      next
    end
    # if we found the stanza, and we match another stanza found_stanza=0
    found_stanza = false if found_stanza && line =~ /\w:/
    # filling the hash table
    next unless found_stanza && line =~ /=/
    line_attribute = line.split('=')
    # chomp and strip here
    key = line_attribute[0].chomp.strip
    value = line_attribute[1].chomp.strip
    # to_sym very important
    current_attributes[key.to_sym] = value
    Chef::Log.debug("chsec: #{desired.stanza} -> [#{key}],[#{value}])")
  end
  # loading the attributes
  attributes current_attributes
end

# update action
action :update do
  chsec_s = "chsec -f #{new_resource.file_name} -s #{new_resource.stanza}"
  change = false
  # iterating trough the hash table of sec attributes
  new_resource.attributes.each do |key, value|
    # checking if value has to be changed
    if new_resource.attributes[key] == current_value.attributes[key]
      Chef::Log.debug("chsec: value of #{key} already set to #{value} for stanza #{new_resource.stanza}")
    else
      change = true
      chsec_s = chsec_s << " -a \"#{key}=#{new_resource.attributes[key]}\""
    end
  end
  if change
    # we converge if the is a change to do
    converge_by("chsec: changing #{new_resource.file_name} for stanza #{new_resource.stanza}") do
      Chef::Log.debug("chsec: command #{chsec_s}")
      shell_out!(chsec_s)
    end
  end
end
