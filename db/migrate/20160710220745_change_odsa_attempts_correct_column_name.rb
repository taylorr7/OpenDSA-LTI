class ChangeOdsaAttemptsCorrectColumnName < ActiveRecord::Migration
  def change
    rename_column :odsa_exercise_attempts, :correct, :worth_credit
    rename_column :odsa_exercise_attempts, :completed, :correct
  end
end
