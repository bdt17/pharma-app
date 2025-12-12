class CreateSupplyChainNodes < ActiveRecord::Migration[8.1]
  def change
    create_table :supply_chain_nodes do |t|
      t.string :node_type
      t.decimal :capacity
      t.decimal :demand
      t.references :truck, null: false, foreign_key: true

      t.timestamps
    end
  end
end
