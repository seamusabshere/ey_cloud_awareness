module EyCloudAwareness
  module HashExt
    # http://as.rubyonrails.org/classes/ActiveSupport/CoreExtensions/Hash/Keys.html
    def underscore_keys!
      keys.each do |key|
        self[key.to_s.underscore] = delete(key)
      end
      self
    end
    
    # http://pragmatig.wordpress.com/2009/04/14/recursive-symbolize_keys/
    def recursive_underscore_keys!
      underscore_keys!
      values.select { |v| v.is_a?(Hash) }.each do |hsh|
        hsh.recursive_underscore_keys!
      end
      # burst thru at least one level of arrays
      values.select { |v| v.is_a?(Array) }.each do |ary|
        ary.each do |v|
          v.recursive_underscore_keys! if v.is_a?(Hash)
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
  end
end

Hash.send :include, EyCloudAwareness::HashExt
