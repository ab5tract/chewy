#####################
# In addtition to being a fierce warrior, Chewbotca had extensive and unbeatable know-how.
# Feel the power of the Source?
## an ab5tract[:ceasless] production
## GPL v2 or higher
#####################
# Automatic tuning to match workload characteristics is contemplated.[citation needed] - a noble, if obstinate, goal

#chewbotca specific
require 'raw_irc'

#standarder fare
require 'socket'
require 'ipaddr'
require 'eventmachine'

module Chewy

  # Module: DCC_Chat
  # Desc: Instantiated by EventMachine
  class DCC_Chat < EventMachine::Connection
    attr_reader :input
    @input = []
    
    def receive_data(data)
      @input ||= []
      
      unless data =~ /^EOF/
        @input << data
      else
        puts @input
        close_connection
        EventMachine::stop
      end
    end
  end

    # Class: Bot
    # Desc: This Bot class exists for the sake of extensibility (multiple bots in the future, etc)

  class Bot
    #include Observable 
    
    attr_reader :server, :port, :nick, :name, :user, :chan, :chans, :socket, :commands
                        
    def initialize(config)
      @server = config[:server]
      @port   = config[:port]
      @user   = config[:user]
      @nick   = config[:nick]
      @pass   = config[:password]
      @name   = config[:name]
      
      # our ip as visible from the outside world, so we can perform DCC chats and sends
      @host_ip = IPAddr.new(getip)
      
      # the hash for the channel is not included in the command line, but may have been specified in 
      # config file
      @chan = config[:channel][/^#/] ? config[:channel] : ('#' + config[:channel])
      
      #@chans should hold a threaded 'watch' on every channel chewy connects to 
      #@chans = Array.new
      
      @masters = config[:masters]
      
      @commands = { :spec => [], :meta => {} }
    end

    def connect
      puts "Connecting to #{@server}:#{@port}..."

      @socket = TCPSocket.new(@server, @port)


      @socket.puts "USER #{@user} #{@nick} #{@name} :#{@name} \r\n"
      @socket.puts "NICK #{@nick} \r\n"
           
      watch_for "IDENTIFY" # wait until we are asked to IDENTIFY, then...
      @socket.puts "PRIVMSG NickServ :IDENTIFY #{@pass}" if @pass  #...identify, if we have a password to use
      
      puts @host_ip
      
      #watch_for "accepted"
      #dcc("chewy")
    end
    
    def join(channel = nil, quit_prev = false)
      channel ||= @chan
      @socket.puts "PART #{channel}" if quit_prev
      @socket.puts "JOIN #{channel} \r\n"
      
      puts "joined the channel"
      
      watch_for "366"
      watch
      #@chans = Thread.new { watch }
    end

    
    # The Bot observes commands that request observation.
    
    def update(cmd)
      @yield = true  if ( cmd.yield2me == true )
      @yield_to = cmd
    end
    
    
    def watch
    begin
      # read the socket, scan the content via Raw class and parse that joint
      while true
        if IO.select([@socket])
          x = @socket.gets
          
            puts x  # this will go to a log once we are out of  debug
          
          raw = Raw.new(x, self)
          if @yield
            @yield_to.catch(raw)
          else
            parse_command raw unless raw.type == :server
          end
        end
      end
    rescue  => error
       puts "#{error.backtrace}"
      @socket.close
    end
    end

    def watch_for(pttrn)
      unmatched = true
      pttrn = Regexp.new(pttrn)
      while unmatched
        if IO.select([@socket])
          x = @socket.gets
          puts x
          unmatched = false if pttrn =~ x
        end
      end
      puts "matched #{pttrn.to_s} in watch_for"
    rescue Exception => error
      @socket.close
    end
    
    def dcc(to)
      local = IPAddr.new "127.0.0.1"
      port = [1856].pack("v*").unpack("v*")
      
      @socket.puts "PRIVMSG #{to} :\01DCC CHAT chat #{local.to_i} #{port}\01"
      
      conns = []
      
      EventMachine::run {
          EventMachine::start_server( "127.0.0.1", 1856, Chewy::DCC_Chat) do |conn|
            conns << conn
          end
        } 
        
        conns[0].input
    end
    
    def getip
      con = Net::HTTP.new('checkip.dyndns.org', 80)
      resp,body = con.get("/", nil)
      ip = body.match(/\d+\.\d+\.\d+\.\d+/)
      
      ip[0]
    end
    
    def say(to, msg)
      i = 0
      splitmsg = msg.split(/\n/)
      splitmsg.each do |part|
        i += 1
        @socket.puts "PRIVMSG #{to} :#{part}"
        sleep(0.2)
        if i == 5
            return
        end
      end
    end

    def parse_command(raw) #:nodoc:
      begin
      is_master = master? raw.sender[:nick]

     # is_identified = raw.body[/^\+/] ? true : false

      #throw :not_identified unless is_identified
      message = raw.body
      
      # we want to send our response according to whether the command was sent to the channel or as a private message
     raw.type == :chan ? (to = raw.to) : (to = raw.sender[:nick])
      
      #if is_master
        @commands[:spec].each do |command|
          if command[:is_public] or is_master
            unless (message.strip =~ command[:regex]).nil?
              params = nil
             
              if message.include? ' '
                params = message.sub(/^\S+\s+(.*)$/, '\1')
              end

              response = command[:callback].call(raw, params)
              say(to, response) unless response.nil?
              
              return
            end
          end
        end
      
       # response = "I don't understand '#{message.strip}' Try saying 'help' " +
       #     "to see what commands I understand."
      #  say(to, response)
      #end
      rescue => error
        puts "Cannot parse command: #{error.to_s}"
      end
    end
    
#    IRC Methods for reacting to Raw.type == :serv
    def pong(line)
        line[0..3] = "PONG"
        @socket.puts "#{line}"
        puts "#{line}"
    end
    
    ################################
#   add_command() and related miscellany
    ################################
    # This command code is mainly a paste job from Jabber::Bot
    # examples at bottom

    def add_command(command, &callback)
      name = command_name(command[:syntax])

      # Add the command meta - used in the 'help' command response.
      add_command_meta(name, command)

      # Add the command spec - used for parsing incoming commands.
      add_command_spec(command, callback)

      # Add any command aliases to the command meta and spec
      unless command[:alias].nil?
        command[:alias].each { |a| add_command_alias(name, a, callback) }
      end
    end

    def add_command_alias(command_name, alias_command, callback) #:nodoc:
      original_command = @commands[:meta][command_name]
      original_command[:syntax] << alias_command[:syntax]

      alias_name = command_name(alias_command[:syntax])

      alias_command[:is_public] = original_command[:is_public]

      add_command_meta(alias_name, original_command, true)
      add_command_spec(alias_command, callback)
    end

    # Add a command meta
    def add_command_meta(name, command, is_alias=false) #:nodoc:
      syntax = command[:syntax]

      @commands[:meta][name] = {
        :syntax      => syntax.is_a?(Array) ? syntax : [syntax],
        :description => command[:description],
        :is_public   => command[:is_public] || false,
        :is_alias    => is_alias
      }
    end

    # Add a command spec
    def add_command_spec(command, callback) #:nodoc:
      @commands[:spec] << {
        :regex     => command[:regex],
        :callback  => callback,
        :is_public => command[:is_public] || false }
    end

    # Extract the command name from the given syntax
    def command_name(syntax) #:nodoc:
      if syntax.include? ' '
        syntax.sub(/^(\S+).*/, '\1')
      else
        syntax
      end
    end
    
    def master?(nick)
      @masters.include? nick
    end
    # Examples:
    #
    #   # Say 'puts foo' or 'p foo' and 'foo' will be written to $stdout.
    #   # The bot will also respond with "'foo' written to $stdout."
    #   add_command(
    #     :syntax      => 'puts <string>',
    #     :description => 'Write something to $stdout',
    #     :regex       => /^puts\s+.+$/,
    #     :alias       => [ :syntax => 'p <string>', :regex => /^p\s+.+$/ ]
    #   ) do |sender, message|
    #     puts "#{sender} says #{message}."
    #     "'#{message}' written to $stdout."
    #   end
    #
    #   # 'puts!' is a non-responding version of 'puts', and has two aliases,
    #   # 'p!' and '!'
    #   add_command(
    #     :syntax      => 'puts! <string>',
    #     :description => 'Write something to $stdout (without response)',
    #     :regex       => /^puts!\s+.+$/,
    #     :alias       => [ 
    #       { :syntax => 'p! <string>', :regex => /^p!\s+.+$/ },
    #       { :syntax => '! <string>', :regex => /^!\s+/.+$/ }
    #     ]
    #   ) do |sender, message|
    #     puts "#{sender} says #{message}."
    #     nil
    #   end
    #
    #  # 'rand' is a public command that produces a random number from 0 to 10
    #  add_command(
    #   :syntax      => 'rand',
    #   :description => 'Produce a random number from 0 to 10',
    #   :regex       => /^rand$/,
    #   :is_public   => true
    #  ) { rand(10).to_s }
  end # Class Bot
end # Module Chewy