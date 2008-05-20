# surfchica.rb - Un Chica Mal

require 'chewy.rb'

@example_config = { :server   =>  'heinlein.freenode.net',
                    :port     =>  '6667',
                    :nick     =>  'chewyBOT',
                    :password   => 'XXXXXXXX',
                    :name     =>  'Chew[bot]ca',
                    :user     =>  'chewychewyHOO',
                    :channel  =>  'waves-shoals',
                    :masters   =>  ['HanSolo'] }

# !---- Add Commands ----!

# 'rand' is a public command that produces a random number from 0 to 10
chewy = Chewy::Bot.new(@default_config)

chewy.add_command(
    :syntax      => 'rand',
    :description => 'Produce a random number from 0 to 10',
    :regex       => /^rand$/,
    :is_public   => true
  ) { rand(10).to_s }

chewy.add_command(
  :syntax   => 'pastie',
  :description => 'For now, just outputs link to pastie.caboo.se',
  :regex    =>  /^pastie$/,
  :is_public  =>  true
) { "http://pastie.caboo.se/"}
surfchica.add_command(
    :syntax      => 'rand',
    :description => 'Produce a random number from 0 to 10',
    :regex       => /^rand$/,
    :is_public   => true
  ) { rand(10).to_s }

surfchica.add_command(
  :syntax   => 'pastie',
  :description => 'For now, just outputs link to pastie.caboo.se',
  :regex    =>  /^pastie$/,
  :is_public  =>  true
) do |raw,parms|
  x = raw.bot.dcc(raw.sender[:nick])
  puts x
  pastie = Pastis.paste "#{x}"
  raw.bot.say(raw.bot.chan, "#{raw.sender[:nick]} has a new pastie: #{pastie.url}")
  nil
end

# requires hacked version of 'cheat' (github.com/ab5tract/cheat)
surfchica.add_command(
  :syntax   => 'cheat',
  :description => 'Chewy helps you cheat (http://cheat.errtheblog.com/)',
  :regex    =>  /^cheat\s+.+$/,
  :is_public  =>  true
) {|sender,params| args = ['--returns']; args << params; Cheat.sheets(args) }

# Does nothing except connect.
surfchica.add_command(
  :syntax => 'dcc',
  :description => 'Establish the facts.',
  :regex => /^dcc/,
  :is_public => true
){ |r,p| r.bot.dcc(r.sender[:nick]) }

chewy.connect
chewy.join