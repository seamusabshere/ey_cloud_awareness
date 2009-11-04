require 'ey_cloud_awareness'

namespace :eyc do
  %w{ app db utility all current first }.each do |name|
    task name do
      puts EngineYardCloudInstance.send(name).map(&:to_hash).to_json
    end
  end
end
