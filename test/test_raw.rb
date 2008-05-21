require File.join(File.dirname(__FILE__), "helper")
 
context "A Raw object created from Chewy's @socket.gets" do
  
  before(:each) do
    @pm_msg = ':automatthew!n=matthew@10.0.0.5 PRIVMSG ab5tract :this is a message only to ab5tract'
    @raw_pm = Chewy::Raw.new(@pm_msg)
    
    @chan_msg = ':automatthew!n=matthew@10.0.0.5 PRIVMSG #waves :this is a message only to #waves'
    @raw_chan = Chewy::Raw.new(@chan_msg)
    
    @chan_msg2 = ':ab5tract!i=HydraIRC@pool-71-175-89-90.phlapa.fios.verizon.net PRIVMSG #waves-shoals :rand'
    @raw_chan2 = Chewy::Raw.new(@chan_msg2)
    
    @serv_msg = ':simmons.freenode.net PONG simmons.freenode.net :LAG191434665'
    @raw_serv = Chewy::Raw.new(@serv_msg)
  end
  
  # implementation testing
  
  specify "is a serv message" do
    @raw_serv.body.should == nil
  end
  
  specify "has a type" do
    @raw_serv.type.should == :server
    @raw_pm.type.should == :pm
    @raw_chan.type.should == :chan
    @raw_chan2.type.should == :chan
  end
  
  specify "has a sender" do
    @raw_pm.sender.should == {:nick=>"automatthew", :name=>"n=matthew", :hostmask=>"10.0.0.5"}
    @raw_chan.sender.should == {:nick=>"automatthew", :name=>"n=matthew", :hostmask=>"10.0.0.5"}
    @raw_chan2.sender.should == {:nick =>"ab5tract", :name => "i=HydraIRC", :hostmask => "pool-71-175-89-90.phlapa.fios.verizon.net" }
  end
  
  specify "has a recipent" do
    @raw_pm.to.should == "ab5tract"
  end
  
  specify "has a body" do
    @raw_pm.body.should == "this is a message only to ab5tract"
    @raw_chan.body.should == "this is a message only to #waves"
  end
  
end