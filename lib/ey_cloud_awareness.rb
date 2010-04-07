require 'open-uri'
require 'set'
require 'fileutils'
require 'json'
require 'yaml'
require 'right_aws' # See aws-s3 compatibility hack below
require 'active_support'
begin; require 'active_support/core_ext/class/inheritable_attributes'; rescue MissingSourceFile; end
begin; require 'active_support/inflector/inflections'; rescue MissingSourceFile; end
begin; require 'active_support/core_ext/string/inflections'; rescue MissingSourceFile; end
begin; require 'active_support/core_ext/hash/keys'; rescue MissingSourceFile; end
begin; require 'active_support/core_ext/array/wrap'; rescue MissingSourceFile; end
require 'engine_yard_cloud_instance'

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
  
  def deep_copy
    Marshal.load Marshal.dump(self)
  end
end

# sabshere 11/05/09
# Compatibility hack for aws-s3/right_aws
# Apologies for rescuing instead of directly checking arity
# I couldn't figure out how to do that because we don't have Module#instance_method
# ... and the class has overridden Object#method (=> "GET"/"POST"/etc)
module Net
  class HTTPGenericRequest
    def exec(sock, ver, path, send_only = nil)   #:nodoc: internal use only
      if @body
        begin
          send_request_with_body sock, ver, path, @body, send_only
        rescue ArgumentError
          $stderr.puts "[EY CLOUD AWARENESS GEM] Rescued from #{$!} because we thought it might have to do with aws-s3/right_aws incompatibility"
          send_request_with_body sock, ver, path, @body
        end
      elsif @body_stream
        begin
          send_request_with_body_stream sock, ver, path, @body_stream, send_only
        rescue ArgumentError
          $stderr.puts "[EY CLOUD AWARENESS GEM] Rescued from #{$!} because we thought it might have to do with aws-s3/right_aws incompatibility"
          send_request_with_body_stream sock, ver, path, @body_stream
        end
      else
        write_header sock, ver, path
      end
    end
  end
end
