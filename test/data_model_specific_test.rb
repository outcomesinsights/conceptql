require_relative "./db_helper"

data_model_test_folder = "./test/lib/conceptql/data_model/#{ENV['CONCEPTQL_DATA_MODEL']}"

Dir["#{data_model_test_folder}/**/*.rb"].each do |f|
  require f
end
