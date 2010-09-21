require 'open-uri'
require 'set'
require 'fileutils'
require 'json'
require 'yaml'
require 'AWS' # aka amazon-ec2
require 'etc'
require 'active_support'
require 'active_support/version'
%w{
  active_support/core_ext/string
  active_support/core_ext/class/inheritable_attributes
  active_support/inflector/inflections
  active_support/core_ext/string/inflections
  active_support/core_ext/hash/keys
  active_support/core_ext/array/wrap
}.each do |active_support_3_requirement|
  require active_support_3_requirement
end if ActiveSupport::VERSION::MAJOR == 3
    
require 'ey_cloud_awareness/engine_yard_cloud_instance'

class Hash
  # http://pragmatig.wordpress.com/2009/04/14/recursive-symbolize_keys/
  def recursive_symbolize_keys!
    symbolize_keys!
    values.select { |v| v.is_a?(Hash) }.each do |hsh|
      hsh.recursive_symbolize_keys!
    end
    # burst thru at least one level of arrays
    values.select { |v| v.is_a?(Array) }.each do |ary|
      ary.each do |v|
        v.recursive_symbolize_keys! if v.is_a?(Hash)
      end
    end
    self
  end
  
  XML_ITEM_KEYS = [ :item, 'item' ]
  
  # :sam => { :item => [{ :foo => :bar }] }
  # into
  # :sam => [{:foo => :bar}]
  def kill_xml_item_keys!
    if keys.length == 1 and XML_ITEM_KEYS.include?(keys.first)
      raise ArgumentError, "You need to call kill_xml_item_keys! on { :foo => { :items => [...] } } not on { :items => [...] }"
    end
    keys.each do |key|
      if self[key].is_a?(Hash) and self[key].keys.length == 1 and XML_ITEM_KEYS.include?(self[key].keys.first)
        # self[:sam] = self[:sam]["item"] (using values.first because we don't know if it's :item or "item")
        self[key] = delete(key).values.first
      end
    end
    self
  end
  
  def recursive_kill_xml_item_keys!
    kill_xml_item_keys!
    values.select { |v| v.is_a?(Hash) }.each do |hsh|
      hsh.recursive_kill_xml_item_keys!
    end
    # burst thru at least one level of arrays
    values.select { |v| v.is_a?(Array) }.each do |ary|
      ary.each do |v|
        v.recursive_kill_xml_item_keys! if v.is_a?(Hash)
      end
    end
    self
  end
  
  def deep_copy
    Marshal.load Marshal.dump(self)
  end
end
