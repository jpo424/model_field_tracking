# Include hook code here
require 'model_field_tracking'
ActiveSupport::Dependencies.autoload_paths << File.expand_path(File.join(File.dirname(__FILE__), %w(lib app models)))
ActiveSupport::Dependencies.autoload_paths << File.expand_path(File.join(File.dirname(__FILE__), %w(lib db migrate)))