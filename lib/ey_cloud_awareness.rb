require 'active_support'
require 'right_aws'

%w{ engine_yard_cloud_instance engine_yard_cloud_chef }.each do |lib|
  require File.expand_path(File.join(File.dirname(__FILE__), lib))
end

# http://pragmatig.wordpress.com/2009/04/14/recursive-symbolize_keys/
class Hash
  def recursive_symbolize_keys!
    symbolize_keys!
    values.select { |v| v.is_a?(Hash) }.each { |h| h.recursive_symbolize_keys! }
    self
  end
end
