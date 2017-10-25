# we should set the locale before the migration
task 'set_locale' do
  I18n.locale = (SiteSetting.default_locale || :en) rescue :en
end

task 'db:environment:set', [:multisite] => [:load_config]  do |_, args|
  if Rails.env.test? && !args[:multisite]
    system("MULTISITE=multisite rails db:environment:set['true'] RAILS_ENV=test")
  end
end

task 'db:create', [:multisite] => [:load_config] do |_, args|
  if Rails.env.test? && !args[:multisite]
    system("MULTISITE=multisite rails db:create['true']")
  end
end

task 'db:drop', [:multisite] => [:load_config] do |_, args|
  if Rails.env.test? && !args[:multisite]
    system("MULTISITE=multisite rails db:drop['true']")
  end
end

# we need to run seed_fu every time we run rails db:migrate
task 'db:migrate', [:multisite] => ['environment', 'set_locale'] do |_, args|
  SeedFu.seed
  Jobs::Onceoff.enqueue_all

  if Rails.env.test? && !args[:multisite]
    system("rails db:schema:dump")
    system("MULTISITE=multisite rails db:schema:load")
    system("RAILS_DB=discourse_test_multisite rails db:migrate['multisite']")
  end
end

task 'test:prepare' => 'environment' do
  I18n.locale = SiteSetting.default_locale rescue :en
  SeedFu.seed
end

task 'db:api_test_seed' => 'environment' do
  puts "Loading test data for discourse_api"
  load Rails.root + 'db/api_test_seeds.rb'
end

def print_table(array)
  width = array[0].keys.map { |k| k.to_s.length }
  cols = array[0].keys.length

  array.each do |row|
    row.each_with_index do |(_, val), i|
      width[i] = [width[i].to_i, val.to_s.length].max
    end
  end

  array[0].keys.each_with_index do |col, i|
    print col.to_s.ljust(width[i], ' ')
    if i == cols - 1
      puts
    else
      print ' | '
    end
  end

  puts "-" * (width.sum + width.length)

  array.each do |row|
    row.each_with_index do |(_, val), i|
      print val.to_s.ljust(width[i], ' ')
      if i == cols - 1
        puts
      else
        print ' | '
      end
    end
  end
end

desc 'Statistics about database'
task 'db:stats' => 'environment' do

  sql = <<~SQL
    select table_name,
    (
      select reltuples::bigint
      from pg_class
      where oid = ('public.' || table_name)::regclass
    ) AS row_estimate,
    pg_size_pretty(pg_relation_size(quote_ident(table_name))) size
    from information_schema.tables
    where table_schema = 'public'
    order by pg_relation_size(quote_ident(table_name)) DESC
  SQL

  puts
  print_table(Post.exec_sql(sql).to_a)
end

desc 'Rebuild indexes'
task 'db:rebuild_indexes' => 'environment' do
  if Import::backup_tables_count > 0
    raise "Backup from a previous import exists. Drop them before running this job with rake import:remove_backup, or move them to another schema."
  end

  Discourse.enable_readonly_mode

  backup_schema = Jobs::Importer::BACKUP_SCHEMA
  table_names = User.exec_sql("select table_name from information_schema.tables where table_schema = 'public'").map do |row|
    row['table_name']
  end

  begin
    # Move all tables to the backup schema:
    User.exec_sql("DROP SCHEMA IF EXISTS #{backup_schema} CASCADE")
    User.exec_sql("CREATE SCHEMA #{backup_schema}")
    table_names.each do |table_name|
      User.exec_sql("ALTER TABLE public.#{table_name} SET SCHEMA #{backup_schema}")
    end

    # Create a new empty db
    Rake::Task["db:migrate"].invoke

    # Fetch index definitions from the new db
    index_definitions = {}
    table_names.each do |table_name|
      index_definitions[table_name] = User.exec_sql("SELECT indexdef FROM pg_indexes WHERE tablename = '#{table_name}' and schemaname = 'public';").map { |x| x['indexdef'] }
    end

    # Drop the new tables
    table_names.each do |table_name|
      User.exec_sql("DROP TABLE public.#{table_name}")
    end

    # Move the old tables back to the public schema
    table_names.each do |table_name|
      User.exec_sql("ALTER TABLE #{backup_schema}.#{table_name} SET SCHEMA public")
    end

    # Drop their indexes
    index_names = User.exec_sql("SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND tablename IN ('#{table_names.join("', '")}')").map { |x| x['indexname'] }
    index_names.each do |index_name|
      begin
        puts index_name
        User.exec_sql("DROP INDEX public.#{index_name}")
      rescue ActiveRecord::StatementInvalid
        # It's this:
        # PG::Error: ERROR:  cannot drop index category_users_pkey because constraint category_users_pkey on table category_users requires it
        # HINT:  You can drop constraint category_users_pkey on table category_users instead.
      end
    end

    # Create the indexes
    table_names.each do |table_name|
      index_definitions[table_name].each do |index_def|
        begin
          User.exec_sql(index_def)
        rescue ActiveRecord::StatementInvalid
          # Trying to recreate a primary key
        end
      end
    end
  rescue
    # Can we roll this back?
    raise
  ensure
    Discourse.disable_readonly_mode
  end
end
