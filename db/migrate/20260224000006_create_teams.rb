# frozen_string_literal: true

class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.text :description
      t.references :owner, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.timestamps
    end

    create_table :memberships do |t|
      t.references :team, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :role, default: 0, null: false
      t.timestamps
    end

    add_index :memberships, [:team_id, :user_id], unique: true

    create_table :team_invitations do |t|
      t.references :team, null: false, foreign_key: { on_delete: :cascade }
      t.references :invited_by, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :email, null: false
      t.string :token, null: false, index: { unique: true }
      t.integer :role, default: 0, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.timestamps
    end

    add_index :team_invitations, [:team_id, :email], unique: true

    add_column :pushes, :team_id, :integer
    add_index :pushes, :team_id
    add_foreign_key :pushes, :teams, on_delete: :nullify
  end
end
