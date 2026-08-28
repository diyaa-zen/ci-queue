# frozen_string_literal: true

module CI
  module Queue
    module ForkPreload
      # Database names interpolate the worker number at YAML-parse time, so every pool the
      # parent built points at worker 1's databases. connects_to per owner is the API that
      # replaces all of an owner's roles together; a handler-level establish_connection
      # replaces only some, leaving a worker reading one database and writing another.
      module Rails
        class << self
          def install
            ForkPreload.after_fork { |_number| rebuild_connection_pools }
          end

          private

          def rebuild_connection_pools
            ActiveRecord::Base.configurations = ::Rails.application.config.database_configuration
            owners_with_roles.each do |owner_name, role_map|
              owner_name.constantize.connects_to(database: role_map)
            end
          end

          def owners_with_roles
            ActiveRecord::Base.connection_handler.connection_pool_list(:all)
                              .each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |pool, owners|
              owners[pool.connection_descriptor.name][pool.role] = pool.db_config.name.to_sym
            end
          end
        end
      end
    end
  end
end
