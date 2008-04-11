class Jobby < ActiveRecord::Migration
  def self.up
    create_table :jobs do |t|
      t.column :freelancer, :string, :null => true
      t.column :path_to_freelancers, :string, :null => false
      t.column :args, :binary
      t.column :status, :string, :null => false, :default => "NEW"
      t.column :priority, :integer, :null => false, :default => 1
      t.column :progress_message, :string, :null => true
      t.column :created_at, :datetime, :null => false
      t.column :started_at, :datetime, :null => true
      t.column :time_to_live, :integer, :null => false
      t.column :version, :integer, :null => false
    end
  end

  def self.down
    drop_table :jobs
  end
end
