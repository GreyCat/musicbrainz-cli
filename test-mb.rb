#!/usr/bin/env ruby

require 'test/unit'

require 'musicbrainzclient'

class TestMusicBrainzClient < Test::Unit::TestCase
  def test_login_bad_credentials
    c = MusicBrainz::Client.new(:user => 'invalid-user', :password => 'invalid-password')
    assert_raise(MusicBrainz::Error) {
      c.login
    }
  end

  def test_login_ok
    c = MusicBrainz::Client.new(:user => 'clitest', :password => '123')
    c.login
  end
end

# Local Variables:
# ruby-indent-level: 2
# ruby-indent-tabs-mode: false
# End:
