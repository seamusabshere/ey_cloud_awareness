class EngineYardCloudInstance
  homedir = File.expand_path "~#{Etc.getpwuid.name}"
  CURRENT_INSTANCE_ID_CACHE_PATH = "#{homedir}/.ey_cloud_awareness/engine_yard_cloud_instance_id"
  CURRENT_SECURITY_GROUP_CACHE_PATH = "#{homedir}/.ey_cloud_awareness/engine_yard_cloud_security_group"
  INSTANCE_DESCRIPTIONS_CACHE_PATH = "#{homedir}/.ey_cloud_awareness/engine_yard_cloud_ec2_instance_descriptions.yml"
  DNA_PATH = '/etc/chef/dna.json'
  
  attr_reader :instance_id
  def initialize(instance_id)
    @instance_id = instance_id.to_s
  end
  
  def valid?
    data.present?
  end
  
  def clear
    self.class.clear
  end
  
  def to_hash
    data.deep_copy
  end
  
  def data
    self.class.data[instance_id.to_sym]
  end
  
  def method_missing(name, *args, &block)
    name = name.to_sym
    if data and data.has_key?(name)
      data[name]
    else
      super
    end
  end
  
  def ==(other)
    self.instance_id == other.instance_id
  end
  
  class_inheritable_accessor :proxy
  
  class << self
    def to_hash
      clear
      data.deep_copy
    end
    
    def from_hash(hash)
      self.proxy = true
      @_data = hash.recursive_symbolize_keys!
      self
    end
    
    def environment
      @_environment ||= first.environment
    end
    
    def app_master
      find_all_by_instance_roles(:app_master).first || find_all_by_instance_roles(:solo).first
    end
    
    def db_master
      find_all_by_instance_roles(:db_master).first || find_all_by_instance_roles(:solo).first
    end
    
    def app
      find_all_by_instance_roles :app, :app_master, :solo
    end
    
    def db
      find_all_by_instance_roles :db_master, :db_slave, :solo
    end
    
    def utility
      find_all_by_instance_roles :utility
    end
    
    def all
      data.map { |k, _| new k }
    end
    
    def with_roles
      all.reject { |i| i.instance_role == 'unknown' }
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
      data.select { |_, v| Array.wrap(args).map(&:to_s).include? v[:instance_role] }.map { |k, _| new k }
    end
    
    def clear
      raise "[EY CLOUD AWARENESS GEM] Can't clear if we used from_hash" if self.proxy
      @_data = nil
      @_dna = nil
      cached_ec2_instance_descriptions true
      cached_current_security_group true
      cached_current_instance_id true
    end
    
    def data
      return @_data if @_data
      raise "[EY CLOUD AWARENESS GEM] Can't calculate data if we used from_hash" if self.proxy
      @_data = Hash.new
      cached_ec2_instance_descriptions.each do |ec2_instance_description|
        @_data[ec2_instance_description['instanceId']] ||= Hash.new
        member = @_data[ec2_instance_description['instanceId']]
        # using instance as a pointer
        if dna[:instance_role] == 'solo'
          member[:instance_role] = 'solo'
        elsif dna[:db_host] == ec2_instance_description['dnsName'] or dna[:db_host] == ec2_instance_description['privateDnsName']
          member[:instance_role] = 'db_master'
        elsif Array.wrap(dna[:db_slaves]).include? ec2_instance_description['privateDnsName']
          member[:instance_role] = 'db_slave'
        elsif Array.wrap(dna[:utility_instances]).include? ec2_instance_description['privateDnsName']
          member[:instance_role] = 'utility'
        elsif dna[:master_app_server][:private_dns_name] == ec2_instance_description['privateDnsName']
          member[:instance_role] = 'app_master'
        elsif ec2_instance_description['instanceState']['name'] == 'running'
          member[:instance_role] = 'app'
        else
          member[:instance_role] = 'unknown'
        end
        member[:group_id] = cached_current_security_group
        member[:users] = dna[:users]
        member[:environment] = dna[:environment]
        @_environment ||= dna[:environment]

        ec2_instance_description.each do |raw_k, raw_v|
          k = raw_k.underscore.to_sym
          next if member.keys.include? k
          member[k] = raw_v
        end
      end
      @_data.recursive_symbolize_keys!
      @_data
    end
    
    def dna
      raise "[EY CLOUD AWARENESS GEM] Can't see DNA if we used from_hash" if self.proxy
      raise "[EY CLOUD AWARENESS GEM] Can't read DNA from #{DNA_PATH}! You should put 'sudo chmod a+r /etc/chef/dna.json' your your before_migrate.rb!" unless File.readable?(DNA_PATH)
      @_dna ||= JSON.load(IO.read(DNA_PATH)).recursive_symbolize_keys!
    end
    
    private
    
    def cached_current_instance_id(refresh = false)
      raise "[EY CLOUD AWARENESS GEM] Can't call current_instance_id if we used from_hash" if self.proxy
      if refresh or !File.readable?(CURRENT_INSTANCE_ID_CACHE_PATH)
        @_cached_current_instance_id = open("http://169.254.169.254/latest/meta-data/instance-id").gets
        begin
          FileUtils.mkdir_p File.dirname(CURRENT_INSTANCE_ID_CACHE_PATH)
          File.open(CURRENT_INSTANCE_ID_CACHE_PATH, 'w') { |f| f.write @_cached_current_instance_id }
        rescue Errno::EACCES
          $stderr.puts "[EY CLOUD AWARENESS GEM] Not caching current instance because #{CURRENT_INSTANCE_ID_CACHE_PATH} can't be written to"
        end
      end
      @_cached_current_instance_id ||= IO.read(CURRENT_INSTANCE_ID_CACHE_PATH)
    end
  

    def cached_current_security_group(refresh = false)
      raise "[EY CLOUD AWARENESS GEM] Can't call current_security_group if we used from_hash" if self.proxy
      if refresh or !File.readable?(CURRENT_SECURITY_GROUP_CACHE_PATH)
        @_cached_current_security_group = open('http://169.254.169.254/latest/meta-data/security-groups').gets
        raise "[EY CLOUD AWARENESS GEM] Don't know how to deal with (possibly) multiple security group: #{@_cached_current_security_group}" if @_cached_current_security_group =~ /,;/
        begin
          FileUtils.mkdir_p File.dirname(CURRENT_SECURITY_GROUP_CACHE_PATH)
          File.open(CURRENT_SECURITY_GROUP_CACHE_PATH, 'w') { |f| f.write @_cached_current_security_group }
        rescue Errno::EACCES
          $stderr.puts "[EY CLOUD AWARENESS GEM] Not caching current security group because #{CURRENT_SECURITY_GROUP_CACHE_PATH} can't be written to"
        end
      end
      @_cached_current_security_group ||= IO.read(CURRENT_SECURITY_GROUP_CACHE_PATH)
    end
    
    def cached_ec2_instance_descriptions(refresh = false)
      raise "[EY CLOUD AWARENESS GEM] Can't call cached_ec2_instance_descriptions if we used from_hash" if self.proxy
      if refresh or !File.readable?(INSTANCE_DESCRIPTIONS_CACHE_PATH)
        ec2 = AWS::EC2::Base.new :access_key_id => dna[:aws_secret_id], :secret_access_key => dna[:aws_secret_key]
        @_cached_ec2_instance_descriptions = ec2.describe_instances
        @_cached_ec2_instance_descriptions.recursive_kill_xml_item_keys!
        @_cached_ec2_instance_descriptions = @_cached_ec2_instance_descriptions['reservationSet'].select { |hash| cached_current_security_group.include? hash['groupSet'].first['groupId'] }
        @_cached_ec2_instance_descriptions.map! { |hash| hash['instancesSet'].first }
        begin
          FileUtils.mkdir_p File.dirname(INSTANCE_DESCRIPTIONS_CACHE_PATH)
          File.open(INSTANCE_DESCRIPTIONS_CACHE_PATH, 'w') { |f| f.write @_cached_ec2_instance_descriptions.to_yaml }
        rescue Errno::EACCES
          $stderr.puts "[EY CLOUD AWARENESS GEM] Not caching instance data because #{INSTANCE_DESCRIPTIONS_CACHE_PATH} can't be written to"
        end
      end
      @_cached_ec2_instance_descriptions ||= YAML.load(IO.read(INSTANCE_DESCRIPTIONS_CACHE_PATH))
    end
  end
end
