class AddDefaultApps < ActiveRecord::Migration
  def self.up
    records = [ "WebROaR Head", "WebROaR Analyzer", "Starling Server", "static-worker", "Admin Panel"]
     records.each do |record|
       App.create({:name => record}) unless App.find(:first, :conditions => ["name= ?", record] )
     end  
  end

  def self.down
  end
end
