require 'sequelizer'

DB = Object.new.extend(Sequelizer).db unless defined?(DB)
unless ENV["LEXICON_URL"]
  $stderr.puts <<END
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Looks like you're running tests without LEXICON_URL set.

I'ma let you finish, but just know that you're probably going
run into some failing tests because they require Lexicon.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

END
end
