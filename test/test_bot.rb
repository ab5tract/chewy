context "A Chewy bot" do

before(:each) do
  @surfchica_config = { :server   =>  'heinlein.freenode.net',
                    :port     =>  '6667',
                    :nick     =>  'surfchica',
                    :pass   => 'surfsup',
                    :name     =>  'Uno Chica Mal',
                    :user     =>  'matzbot',
                    :channel  =>  '#waves',
                    :masters   =>  ['ab5tract'] }
   @surfchica = Chewy::Bot.new(@surfchica_config)

    @surfchica.add_command(
    :syntax      => 'rand',
    :description => 'Produce a random number from 0 to 10',
    :regex       => /^rand$/,
    :is_public   => true
  ) { "11" }

  @rand_msg = ":ab5tract!i=HydraIRC@pool-71-175-89-90.phlapa.fios.verizon.net PRIVMSG #waves-shoals :rand"
  @rand_raw = Chewy::Raw.new(@rand_msg)
end

specify "has a master" do
  @surfchica.master?("ab5tract").should == true
end

specify "can parse command" do
 #@surfchica.parse_command(@rand_raw).message.should == "rand"
end
  
end