require 'socket'

module Chewy

  # Class: Raw
  # Desc:  This class represents the raw IRC commands coming in through the socket.
  class Raw
    attr_accessor :sender, :body, :type, :to, :raw, :cmd, :args

    def initialize(raw, bot = nil)
    begin
      pm = "not_nil"
      (pm = nil) unless (m = raw.match(Raw.pm_regex))
      @type = :server if pm.nil?
      
      unless @type == :server
        @raw                = raw   # also, m[0]
        @sender             = {}
        @sender[:nick]      = m[1]
        @sender[:name]      = m[2]
        @sender[:hostmask]  = m[3]
        @to                 = m[4]
        @body               = m[5]

        # the presence of '#' means the message was bound for a channel
        #   otherwise, it's a private message to a user
        @type = @to.match( /^#/ ) ? :chan : :pm
      
        # check to see if the message is ctcp
        if (@type == :pm and @body[/\01/])
          @type = :ctcp
        end
      else
       bot.pong(raw) if raw[0..3] == "PING"
      end
    rescue => er
      puts "Raw failed to initialize: #{er.to_s}"
    end
    end
    
    def Raw.pm_regex
      @pm_regex ||= /^\:(.+)\!\~?(.+)\@(.+) PRIVMSG (\#?.+) \:(.+)/
    end

  end

    # Class: Bot
    # Desc: This Bot class exists for the sake of extensibility (multiple bots in the future, etc)

  class Bot
    attr_accessor :server, :port, :nick, :name, :user, :pass, :chan, :chans, :socket, :commands
                        
    def initialize(config)
      @server = config[:server]
      @port   = config[:port]
      @user   = config[:user]
      @nick   = config[:nick]
      @pass   = config[:password]
      @name   = config[:name]
      
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
  
    def watch
    begin
      # read the socket, scan the content via Raw class and parse that joint
      while true
        if IO.select([@socket])
          x = @socket.gets
          puts x
          raw = Raw.new(x, self)
          puts raw.body
          parse_command raw unless raw.type == :server
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
    
    def say(to, msg)
      @socket.puts "PRIVMSG #{to} :#{msg}"
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

              response = command[:callback].call(raw.sender[:nick], params)
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
