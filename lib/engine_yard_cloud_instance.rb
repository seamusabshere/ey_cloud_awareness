class EngineYardInstance
  attr_accessor :instance_id
  def initialize(instance_id)
    @instance_id = instance_id
  end
  
  def method_missing(name, *args, &block)
    name = name.to_sym
    if me = self.class.data[instance_id] and me.has_key?(name)
      me[name]
    else
      super
    end
  end
  
  class << self
    def find_all_by_instance_roles(*args)
      data.select { |_, v| Array.wrap(args).include? v[:instance_role] }.map { |k, _| new k }
    end
    
    def app_instances
      find_all_by_instance_roles :app, :app_master
    end
    
    def db_instances
      find_all_by_instance_roles :db
    end
    
    def utility_instances
      find_all_by_instance_roles :utility
    end
    
    def data
      return @_data if @_data
      ec2 = RightAws::Ec2.new dna[:aws_secret_id], dna[:aws_secret_key]
      hash = Hash.new
      ec2.describe_instances.each do |instance_description|
        key = instance_description[:aws_instance_id]
        hash[key] ||= Hash.new
        current = hash[key]
        # using current as a pointer
        if dna[:db_host] == instance_description[:dns_name] or dna[:db_host] == instance_description[:private_dns_name]
          current[:instance_role] = :db
        elsif Array.wrap(dna[:utility_instances]).include? instance_description[:private_dns_name]
          current[:instance_role] = :utility
        elsif dna[:master_app_server][:private_dns_name] == instance_description[:private_dns_name]
          current[:instance_role] = :app_master
        else
          current[:instance_role] = :app
        end
        current[:private_dns_name] = instance_description[:private_dns_name]
        current[:dns_name] = instance_description[:dns_name]
        current[:aws_instance_id] = instance_description[:aws_instance_id]
        current[:aws_state] = instance_description[:aws_state]
      end
      @_data = hash
    end
    
    def dna
      EngineYardChef.dna
    end
  end
end
