# frozen_string_literal: true

Dir['./test/**/*_test.rb'].sort.each do |f|
  require f
end
