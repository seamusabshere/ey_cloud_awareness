class EngineYardCloudInstance
  CURRENT_INSTANCE_ID_CACHE_PATH = defined?(RAILS_ROOT) ? "#{RAILS_ROOT}/config/engine_yard_cloud_instance_id" : '/etc/engine_yard_cloud_instance_id'
  CURRENT_SECURITY_GROUPS_CACHE_PATH = defined?(RAILS_ROOT) ? "#{RAILS_ROOT}/config/engine_yard_cloud_security_groups" : '/etc/engine_yard_cloud_security_groups'
  INSTANCE_DESCRIPTIONS_CACHE_PATH = defined?(RAILS_ROOT) ? "#{RAILS_ROOT}/config/engine_yard_cloud_instance_descriptions.yml" : '/etc/engine_yard_cloud_instance_descriptions.yml'
  DNA_PATH = '/etc/chef/dna.json'
  
  attr_reader :instance_id
  def initialize(instance_id)
    @instance_id = instance_id.to_sym
  end
  
  def valid?
    data.present?
  end
  
  def refresh
    self.class.refresh
  end
  
  def data
    self.class.data[instance_id]
  end
  
  def method_missing(name, *args, &block)
    name = name.to_sym
    if data and data.has_key?(name)
      data[name]
    else
      super
    end
  end
  
  class << self
    def app
      find_all_by_instance_roles :app, :app_master
    end
    
    def db
      find_all_by_instance_roles :db
    end
    
    def utility
      find_all_by_instance_roles :utility
    end
    
    def all
      data.map { |k, _| new k }
    end
    
    def current
      new cached_current_instance_id
    end
    
    def first
      new data.to_a.first.first
    end
    
    def find_by_instance_id(instance_id)
      new instance_id
    end
    
    def find_all_by_instance_roles(*args)
      data.select { |_, v| Array.wrap(args).include? v[:instance_role] }.map { |k, _| new k }
    end
    
    def refresh
      @_data = nil
      @_dna = nil
      cached_instance_descriptions true
      cached_current_security_groups true
      cached_current_instance_id true
    end
    
    def data
      return @_data if @_data
      hash = Hash.new
      cached_instance_descriptions.each do |instance_description|
        next unless Set.new(Array.wrap(cached_current_security_groups)).superset? Set.new(instance_description[:aws_groups])
        hash[instance_description[:aws_instance_id]] ||= Hash.new
        current = hash[instance_description[:aws_instance_id]]
        # using current as a pointer
        if dna[:db_host] == instance_description[:dns_name] or dna[:db_host] == instance_description[:private_dns_name]
          current[:instance_role] = :db
        elsif Array.wrap(dna[:utility_instances]).include? instance_description[:private_dns_name]
          current[:instance_role] = :utility
        elsif dna[:master_app_server][:private_dns_name] == instance_description[:private_dns_name]
          current[:instance_role] = :app_master
        elsif instance_description[:aws_state] == 'running'
          current[:instance_role] = :app
        end
        current[:private_dns_name] = instance_description[:private_dns_name]
        current[:dns_name] = instance_description[:dns_name]
        current[:aws_state] = instance_description[:aws_state]
        current[:aws_groups] = instance_description[:aws_groups]
      end
      @_data = hash.recursive_symbolize_keys!
    end
    
    def dna
      @_dna ||= JSON.load(IO.read(DNA_PATH)).recursive_symbolize_keys!
    end
    
    private
    
    # def cached_current_instance_id
    # def cached_current_security_groups
    %w{ current_instance_id current_security_groups }.each do |name|
      eval %{
        def cached_#{name}(refresh = false)
          if refresh or !File.readable?(#{name.upcase}_CACHE_PATH)
            @_cached_#{name} = open("http://169.254.169.254/latest/meta-data/#{name.gsub('current_', '').dasherize}").gets
            begin
              File.open(#{name.upcase}_CACHE_PATH, 'w') { |f| f.write @_cached_#{name} }
            rescue Errno::EACCES
              $stderr.puts "[EY CLOUD AWARENESS GEM] Not caching #{name.humanize.downcase} because \#{#{name.upcase}_CACHE_PATH} can't be written to"
            end
          end
          @_cached_#{name} ||= IO.read(#{name.upcase}_CACHE_PATH)
        end
      }
    end
    
    def cached_instance_descriptions(refresh = false)
      if refresh or !File.readable?(INSTANCE_DESCRIPTIONS_CACHE_PATH)
        ec2 = RightAws::Ec2.new dna[:aws_secret_id], dna[:aws_secret_key]
        @_cached_instance_descriptions = ec2.describe_instances.map(&:recursive_symbolize_keys!)
        begin
          File.open(INSTANCE_DESCRIPTIONS_CACHE_PATH, 'w') { |f| f.write @_cached_instance_descriptions.to_yaml }
        rescue Errno::EACCES
          $stderr.puts "[EY CLOUD AWARENESS GEM] Not caching instance data because #{INSTANCE_DESCRIPTIONS_CACHE_PATH} can't be written to"
        end
      end
      @_cached_instance_descriptions ||= YAML.load(IO.read(INSTANCE_DESCRIPTIONS_CACHE_PATH))
    end
  end
end
