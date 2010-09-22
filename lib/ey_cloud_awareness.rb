require 'open-uri'
require 'set'
require 'fileutils'
require 'AWS' # aka amazon-ec2
require 'etc'
require 'active_support'
require 'active_support/version'
%w{
  active_support/json
  active_support/core_ext/string
  active_support/core_ext/class/attribute_accessors
  active_support/inflector/inflections
  active_support/core_ext/string/inflections
  active_support/core_ext/hash/keys
  active_support/core_ext/array/wrap
}.each do |active_support_3_requirement|
  require active_support_3_requirement
end if ActiveSupport::VERSION::MAJOR == 3
    
require 'ey_cloud_awareness/engine_yard_cloud_instance'
require 'ey_cloud_awareness/hash_ext'

module EyCloudAwareness
end
