module MusicBrainz
  VERSION = '0.1'

  class Error < RuntimeError; end

  class Entity
    attr_reader :type, :uuid

    def initialize(type, uuid)
      @type = type
      @uuid = uuid
    end

    def self.parse(str)
      raise Error.new("Unable to parse \"#{str}\" as entity specification") unless str =~ /(work|recording)\/([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})/
      return self.new($1, $2)
    end
  end

  class Client
    TMPDIR = '.'
    COOKIES = "#{TMPDIR}/cookies.txt"

    attr_accessor :username, :password, :host, :user_agent, :message

    def initialize(opt = {})
      @user = opt[:user] if opt[:user]
      @password = opt[:password] if opt[:password]
      @host = opt[:host] || ENV['MBHOST'] || 'test.musicbrainz.org'
      @user_agent = opt[:user_agent] || ENV['USER_AGENT'] || "MusicBrainzCLI/#{VERSION}"
      @message = opt[:message]
    end

    def login
      raise Error.new("No user specified") if @user.nil? or @user.empty?
      raise Error.new("No password specified") if @password.nil? or @password.empty?
      out = query("http://#{@host}/login", "username=#{@user}&password=#{@password}&remember_me=1")

      if out =~ /<span class="error">(.*)<\/span>/
        msg = $1
        msg.gsub!(/<[^>]*>/, '')
        raise Error.new(msg)
      end
    end

    def relate(a, type, b)
      # Swap to make canonical form of relationships
      if a.type == 'work' and b.type == 'recording'
        t = a
        a = b
        b = t
      end

      case "#{a.type}_#{b.type}"
      when 'recording_work'
        case type
        when 'medley' then type_idx = 244
        when 'performance' then type_idx = 278
        else raise Error.new("Unable to handle relationship type \"#{type}\"")
        end
      else
        raise Error.new("Unable to handle entities pair: #{a.type} <=> #{b.type}")
      end

      retries = 3
      begin
        retries -= 1
        res = query(
          "http://#{@host}/edit/relationship/create?type1=#{b.type}&entity1=#{b.uuid}&entity0=#{a.uuid}&type0=#{a.type}",
          "ar.link_type_id=#{type_idx}&ar.edit_note=#{@message}&ar.as_auto_editor=1"
        )
        case res
        when /You need to be logged in to view this page./
          login
          retry if retries > 0
        when /A relationship between .* and .* already/
          raise Error.new('Relationship already exists')
        when /(Thank you, your edit has been entered into the edit queue for peer review|Thank you, your edit has been accepted and applied)/
          return
        else
          raise Error.new('Unable to parse reply for /edit/relationship/create')
        end
      end
    end

    private
    def query(url, post_data = nil)
      tmpfile = "#{TMPDIR}/temp#{rand(1e10)}.html"
      cmdline = ['wget']
      cmdline << "--load-cookies '#{COOKIES}'"
      cmdline << "--save-cookies '#{COOKIES}'"
      cmdline << "--keep-session-cookies"
      cmdline << "--user-agent '#{@user_agent}'"
      cmdline << "-a#{TMPDIR}/wget.log"
      cmdline << "-O#{tmpfile}"
      cmdline << "--post-data '#{post_data}'" if post_data
      cmdline << "'#{url}'"

      cmdline = cmdline.join(' ')

      puts cmdline
      system(cmdline)

      l = nil
      File.open(tmpfile, 'r') { |f| l = f.read }
      return l
    end
  end
end

# Local Variables:
# ruby-indent-level: 2
# ruby-indent-tabs-mode: nil
# indent-tabs-mode: nil
# End:
