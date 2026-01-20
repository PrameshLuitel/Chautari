class RenameModelNameToAiModelNameInAiConfigs < ActiveRecord::Migration[7.0]
  def change
    rename_column :ai_configs, :model_name, :ai_model_name
  end
end
