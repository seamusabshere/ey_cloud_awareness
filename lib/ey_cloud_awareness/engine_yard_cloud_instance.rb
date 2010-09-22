class EngineYardCloudInstance
  HOMEDIR = File.expand_path "~#{Etc.getpwuid.name}"
  PRESENT_INSTANCE_ID_CACHE_PATH = "#{HOMEDIR}/.ey_cloud_awareness/engine_yard_cloud_instance_id"
  PRESENT_SECURITY_GROUP_CACHE_PATH = "#{HOMEDIR}/.ey_cloud_awareness/engine_yard_cloud_security_group"
  INSTANCES_CACHE_PATH = "#{HOMEDIR}/.ey_cloud_awareness/engine_yard_cloud_ec2_instances.json"
  DNA_PATH = '/etc/chef/dna.json'
  
  attr_reader :instance_id
  def initialize(instance_id)
    @instance_id = instance_id.to_s
  end
  
  def clear
    self.class.clear
  end
  
  def to_hash
    data.merge 'environment' => environment,
               'apps' => apps,
               'users' => users
  end
  
  def app
    raise "[EY CLOUD AWARENESS GEM] There is more than one app on this instance, so you can't use the #app method. Use #users.first (etc.) instead." if apps.length > 1
    apps.first
  end
  
  def user
    raise "[EY CLOUD AWARENESS GEM] There is more than one user on this instance, so you can't use the #user method. Use #users.first (etc.) instead." if users.length > 1
    users.first
  end

  def as_json(*)
    to_hash
  end
  
  def data
    self.class.data['instances'][instance_id]
  end
  
  def method_missing(name, *args, &block)
    if data and data.has_key?(name.to_s)
      data[name.to_s]
    elsif self.class.data and self.class.data.has_key?(name.to_s)
      self.class.data[name.to_s]
    else
      super
    end
  end
  
  def ==(other)
    self.instance_id == other.instance_id
  end
  
  cattr_accessor :proxy
  cattr_accessor :data_cache
  cattr_accessor :dna_cache
  
  class << self
    # sabshere 9/21/10 from engineyard gem cli.rb
    # def ssh_host_filter(opts)
    #   return lambda {|instance| true }                                                if opts[:all]
    #   return lambda {|instance| %w(solo app app_master    ).include?(instance.role) } if opts[:app_servers]
    #   return lambda {|instance| %w(solo db_master db_slave).include?(instance.role) } if opts[:db_servers ]
    #   return lambda {|instance| %w(solo db_master         ).include?(instance.role) } if opts[:db_master  ]
    #   return lambda {|instance| %w(db_slave               ).include?(instance.role) } if opts[:db_slaves  ]
    #   return lambda {|instance| %w(util                   ).include?(instance.role) &&
    #                                        opts[:utilities].include?(instance.name) } if opts[:utilities  ]
    #   return lambda {|instance| %w(solo app_master        ).include?(instance.role) }
    # end
    
    def all
      data['instances'].map { |instance_id, _| new instance_id }
    end
    
    def app_servers
      find_all_by_instance_roles 'app', 'app_master', 'solo'
    end
    
    def db_servers
      find_all_by_instance_roles 'db_master', 'db_slave', 'solo'
    end

    def db_master
      find_all_by_instance_roles('db_master').first || find_all_by_instance_roles('solo').first
    end
    
    def db_slaves
      find_all_by_instance_roles 'db_slave'
    end
    
    def utilities
      find_all_by_instance_roles 'util'
    end
    
    def app_master
      find_all_by_instance_roles('app_master').first || find_all_by_instance_roles('solo').first
    end
    
    def with_roles
      all.select { |i| i.role.present? }
    end
    
    def present
      new present_instance_id
    end
    
    def find_by_instance_id(instance_id)
      new instance_id
    end
    
    def find_all_by_instance_roles(*args)
      data['instances'].select { |_, instance| Array.wrap(args).map(&:to_s).include? instance['role'] }.map { |instance_id, _| new instance_id }
    end
    
    def clear
      raise "[EY CLOUD AWARENESS GEM] Can't clear if we used from_hash" if proxy?
      self.data_cache = nil
      self.dna_cache = nil
      ec2_instances true
      present_security_group true
      present_instance_id true
    end
    
    def data
      return data_cache if data_cache.is_a? Hash
      raise "[EY CLOUD AWARENESS GEM] Can't calculate data if we used from_hash" if proxy?
      self.data_cache = Hash.new
      data_cache['instances'] = mixed_instances
      data_cache['environment'] = dna['engineyard']['environment'].except('instances', 'apps')
      data_cache['apps'] = dna['engineyard']['environment']['apps']
      data_cache['users'] = dna['users']
      data_cache['group_id'] = present_security_group
      data_cache
    end
    
    def proxy?
      !!proxy
    end
    
    def to_hash
      data
    end
    
    def as_json(*)
      to_hash
    end
    
    def from_json(str)
      from_hash ActiveSupport::JSON.decode(str)
    end
    
    def from_hash(hash)
      self.proxy = true
      self.data_cache = hash
      self
    end
    
    def method_missing(name, *args, &block)
      if data and data.has_key?(name.to_s)
        data[name.to_s]
      else
        super
      end
    end
    
    def mixed_instances
      ec2_instances.inject(Hash.new) do |memo, ec2_instance|
        instance_id = ec2_instance['instance_id']
        mixed_instance = dna_instances.detect { |dna_instance| dna_instance['id'] == instance_id }.merge ec2_instance
        memo[instance_id] = mixed_instance
        memo
      end
    end
    
    def dna_instances
      dna['engineyard']['environment']['instances']
    end
    
    def dna
      raise "[EY CLOUD AWARENESS GEM] Can't see DNA if we used from_hash" if proxy?
      raise "[EY CLOUD AWARENESS GEM] Can't read DNA from #{DNA_PATH}! You should put 'sudo chmod a+r /etc/chef/dna.json' your your before_migrate.rb!" unless File.readable?(DNA_PATH)
      self.dna_cache ||= ActiveSupport::JSON.decode(IO.read(DNA_PATH))
    end
    
    def present_instance_id(refresh = false)
      raise "[EY CLOUD AWARENESS GEM] Can't call present_instance_id if we used from_hash" if proxy?
      if refresh or !File.readable?(PRESENT_INSTANCE_ID_CACHE_PATH)
        @_present_instance_id = open("http://169.254.169.254/latest/meta-data/instance-id").gets
        begin
          FileUtils.mkdir_p File.dirname(PRESENT_INSTANCE_ID_CACHE_PATH)
          File.open(PRESENT_INSTANCE_ID_CACHE_PATH, 'w') { |f| f.write @_present_instance_id }
        rescue Errno::EACCES
          $stderr.puts "[EY CLOUD AWARENESS GEM] Not caching present instance because #{PRESENT_INSTANCE_ID_CACHE_PATH} can't be written to"
        end
      end
      @_present_instance_id ||= IO.read(PRESENT_INSTANCE_ID_CACHE_PATH)
    end

    def present_security_group(refresh = false)
      raise "[EY CLOUD AWARENESS GEM] Can't call present_security_group if we used from_hash" if proxy?
      if refresh or !File.readable?(PRESENT_SECURITY_GROUP_CACHE_PATH)
        @_present_security_group = open('http://169.254.169.254/latest/meta-data/security-groups').gets
        raise "[EY CLOUD AWARENESS GEM] Don't know how to deal with (possibly) multiple security group: #{@_present_security_group}" if @_present_security_group =~ /,;/
        begin
          FileUtils.mkdir_p File.dirname(PRESENT_SECURITY_GROUP_CACHE_PATH)
          File.open(PRESENT_SECURITY_GROUP_CACHE_PATH, 'w') { |f| f.write @_present_security_group }
        rescue Errno::EACCES
          $stderr.puts "[EY CLOUD AWARENESS GEM] Not caching present security group because #{PRESENT_SECURITY_GROUP_CACHE_PATH} can't be written to"
        end
      end
      @_present_security_group ||= IO.read(PRESENT_SECURITY_GROUP_CACHE_PATH)
    end
    
    def ec2_instances(refresh = false)
      raise "[EY CLOUD AWARENESS GEM] Can't call ec2_instances if we used from_hash" if proxy?
      if refresh or !File.readable?(INSTANCES_CACHE_PATH)
        ec2 = AWS::EC2::Base.new :access_key_id => dna['aws_secret_id'], :secret_access_key => dna['aws_secret_key']
        @_ec2_instances = ec2.describe_instances
        @_ec2_instances.recursive_kill_xml_item_keys!
        @_ec2_instances = @_ec2_instances['reservationSet'].select { |hash| present_security_group.include? hash['groupSet'].first['groupId'] }
        @_ec2_instances.map! { |hash| hash['instancesSet'].first.recursive_underscore_keys! }
        begin
          FileUtils.mkdir_p File.dirname(INSTANCES_CACHE_PATH)
          File.open(INSTANCES_CACHE_PATH, 'w') { |f| f.write @_ec2_instances.to_json }
        rescue Errno::EACCES
          $stderr.puts "[EY CLOUD AWARENESS GEM] Not caching instance data because #{INSTANCES_CACHE_PATH} can't be written to"
        end
      end
      @_ec2_instances ||= ActiveSupport::JSON.decode(IO.read(INSTANCES_CACHE_PATH))
    end
  end
end
