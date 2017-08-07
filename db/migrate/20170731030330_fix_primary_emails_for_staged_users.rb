class FixPrimaryEmailsForStagedUsers < ActiveRecord::Migration
  def up
    execute <<~SQL
    INSERT INTO user_emails (
      user_id,
      email,
      "primary",
      created_at,
      updated_at
    ) SELECT
      users.id,
      email_tokens.email,
      'TRUE',
      users.created_at,
      users.updated_at
    FROM users
    LEFT JOIN user_emails ON user_emails.user_id = users.id
    LEFT JOIN email_tokens ON email_tokens.user_id = users.id
    WHERE staged
    AND NOT active
    AND user_emails.id IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
