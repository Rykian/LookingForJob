class CreatePipelineErrors < ActiveRecord::Migration[8.1]
  def change
    create_table :pipeline_errors do |t|
      t.references :job_offer, null: true, foreign_key: true
      t.references :run, null: true, foreign_key: true
      t.string :step, null: false
      t.string :source, null: true
      t.integer :step_version, null: true
      t.string :error_class, null: false
      t.text :error_message, null: false
      t.jsonb :arguments, null: false, default: {}
      t.boolean :resolved, null: false, default: false

      t.timestamps
    end

    add_index :pipeline_errors, :step
    add_index :pipeline_errors, :resolved
    add_index :pipeline_errors, [:job_offer_id, :step, :resolved]
  end
end
