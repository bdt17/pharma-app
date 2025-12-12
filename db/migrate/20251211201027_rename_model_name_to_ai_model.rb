class RenameModelNameToAiModel < ActiveRecord::Migration[8.0]
  def change
    rename_column :ai_providers, :model_name, :ai_model
  end
end
