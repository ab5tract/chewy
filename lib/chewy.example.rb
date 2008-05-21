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

chewy.connect
chewy.join