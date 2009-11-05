require 'open-uri'
require 'set'
require 'active_support'
require 'right_aws' # See aws-s3 compatibility hack below
require File.expand_path(File.join(File.dirname(__FILE__), 'engine_yard_cloud_instance'))

class Hash
  # http://pragmatig.wordpress.com/2009/04/14/recursive-symbolize_keys/
  def recursive_symbolize_keys!
    symbolize_keys!
    values.select { |v| v.is_a?(Hash) }.each { |h| h.recursive_symbolize_keys! }
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
