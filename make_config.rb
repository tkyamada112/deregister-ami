require 'yaml'
require 'unindent'

CONFIG_DIR = "."
KEEP_DAYS  = "30".freeze
KEEP_COUNT = "20".freeze
SERVICE_NAME = ARGV[0]

def initial_define(env)
config_initial = <<-EOS.unindent
  #{env}:
    keep_days: #{KEEP_DAYS}
    keep_count: #{KEEP_COUNT}
EOS
end

def role_define(env)
  case env
  when "DEV" then
    environment = "develop"
  when "STG" then
    environment = "staging"
  when "PRD" then
    environment = "product"
  end

  role_names = []
  ARGV.reverse_each do |role_name|
    if "#{role_name}" == "#{SERVICE_NAME}"
      break
    end
    role_names << "    - #{SERVICE_NAME}_#{role_name}_#{environment}"
  end
  role_names.reverse
end

config_file = File.open("#{CONFIG_DIR}/config.yml","w")
%w(DEV STG PRD).each do |environment|
  initial_part = initial_define(environment)
  role_part    = role_define(environment)

  config_file.puts(initial_part)
  config_file.puts("  del_target_ami_name:")
  config_file.puts(role_part)
  config_file.puts("")
end
