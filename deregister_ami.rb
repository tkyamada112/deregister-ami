require 'aws-sdk'
require 'time'
require 'yaml'

def filtering_expired_day(ec2_client, ami_name, owner_id, delete_threshold_day)
  expired_images = []
  begin 
    ec2_client.describe_images(
      {
        filters: [
          {
            name: "name",
            values: ["#{ami_name}"]
          },
          {
            name: "state",
            values: ["available","failed"]
          },
          {
            name: "owner-id",
            values: ["#{owner_id}"]
          }
        ]
      }
    ).images.each do |filtered_ami|
      simple_ami_info = {
        "ami_name"       => filtered_ami.name,
        "ami_createdate" => filtered_ami.creation_date,
        "ami_id"         => filtered_ami.image_id
      }
      expired_images << simple_ami_info if (Time.now.utc - Time.parse(simple_ami_info["ami_createdate"])) / 60 > delete_threshold_day
    end
  rescue => err
    puts err
    exit 1
  end
  expired_images
end

def filtering_excess_count(day_filtered_amis, ami_name, delete_threshold_count)
   excess_image_ids = []
   if day_filtered_amis.size <= delete_threshold_count.to_i then
    puts "InstanceRole: #{ami_name} Can not Find the AMI that a able to delete."
   elsif day_filtered_amis.size > delete_threshold_count.to_i then 
    day_filtered_amis.sort_by{|expire_ami| expire_ami["ami_createdate"]}.first(day_filtered_amis.size - delete_threshold_count.to_i).each do |excess_image|
      puts "InstanceRole: #{ami_name} to be delete. AMIID: #{excess_image["ami_id"]} (#{Time.parse(excess_image["ami_createdate"])})"
      excess_image_ids << excess_image["ami_id"]
    end
  end
  excess_image_ids 
end

def delete_ami(ec2_client, excess_image_ids)
  excess_image_ids.each do |excess_image_id|
  begin 
    ec2_client.deregister_image(:image_id => excess_image_id)
  rescue => err
    puts err
    exit 1
  end
  end
end

def generate_ec2_client(env)
  begin 
    ec2_client = Aws::EC2::Client.new(
        access_key_id:     ENV["#{env}_AWS_ACCESS_KEY_ID"],
        secret_access_key: ENV["#{env}_AWS_SECRET_KEY_ID"],
        region:            ENV["#{env}_AWS_DEFAULT_REGION"]
      )
  rescue => err
    puts err
    exit 1
  end
end

for env in %w(DEV STG PRD) do
  env_config = YAML.load_file('config.yml')[env]

  case env
  when "DEV"
    owner_id = ENV["DEV_ACCOUNT_ID"]
    delete_threshold_day   = env_config["keep_days"] * (60 * 24)
    delete_threshold_count = env_config["keep_count"]
    ami_names              = env_config["del_target_ami_name"]
  when "STG"
    owner_id = ENV["STG_ACCOUNT_ID"]
    delete_threshold_day   = env_config["keep_days"] * (60 * 24)
    delete_threshold_count = env_config["keep_count"]
    ami_names              = env_config["del_target_ami_name"]
  when "PRD"
    owner_id = ENV["PRD_ACCOUNT_ID"]
    delete_threshold_day   = env_config["keep_days"] * (60 * 24)
    delete_threshold_count = env_config["keep_count"]
    ami_names              = env_config["del_target_ami_name"]
  else
    puts "invalid environment"
    exit 1
  end

  ec2_client = generate_ec2_client(env)
  ami_names.each do |ami_name|
    filtered_expire_day = filtering_expired_day(ec2_client, ami_name, owner_id, delete_threshold_day)
    excess_image_ids    = filtering_excess_count(filtered_expire_day, ami_name, delete_threshold_count)
    delete_ami(ec2_client, excess_image_ids)
  end
end
