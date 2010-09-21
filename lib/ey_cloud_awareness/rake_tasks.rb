require 'ey_cloud_awareness'

namespace :eyc do
  task :to_json do
    puts EngineYardCloudInstance.to_hash.to_json
  end
end
