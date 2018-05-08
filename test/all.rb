Dir['./test/**/*_test.rb'].each do |f|

  data_model_test = "./test/lib/conceptql/data_model"

  # Test all non data model specifc tests not related to operators
  unless f.include?(data_model_test)
    p f
    p "#{ENV['DATA_MODEL']}_test.rb"
    require f
  end

  # Test the data model specific tests
  require "#{data_model_test}/#{ENV['DATA_MODEL']}_test.rb"
end
