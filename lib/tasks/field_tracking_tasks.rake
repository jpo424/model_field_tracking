namespace :db do
  namespace :migrate do
    namespace :field_tracking do
      description = "Runs Migrations from vendor/plugins/model_field_tracking/lib/db/migrate to CREATE field_changes table"
      desc description
      task :up => :environment do
        CreateFieldTrackingSchema.up
      end
      description = "Runs Migrations from vendor/plugins/model_field_tracking/lib/db/migrate to REMOVE field_changes table"
      desc description
      task :down => :environment do
        CreateFieldTrackingSchema.down
      end
    end
  end
end
