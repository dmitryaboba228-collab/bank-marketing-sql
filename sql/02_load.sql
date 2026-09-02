--  Загрузка нормализованных CSV в PostgreSQL
-- Выполнять после того как отработал 01_schema.sql.

begin;

-- Повторный прогон не должен падать на дубликатах.
-- RESTART IDENTITY сбрасывает счётчик contact_id.

truncate previous_campaign, contacts, clients,
         jobs, marital_statuses, education_levels,
         contact_channels, campaign_outcomes
    restart identity cascade;

-- справочники
copy jobs (job_id, job_name)
    from '/Users/Shared/bank_data/jobs.csv' with (format csv, header true);

copy marital_statuses (marital_id, status_name)
    from '/Users/Shared/bank_data/marital_statuses.csv' with (format csv, header true);

copy education_levels (education_id, level_name)
    from '/Users/Shared/bank_data/education_levels.csv' with (format csv, header true);

copy contact_channels (channel_id, channel_name)
    from '/Users/Shared/bank_data/contact_channels.csv' with (format csv, header true);

copy campaign_outcomes (outcome_id, outcome_name)
    from '/Users/Shared/bank_data/campaign_outcomes.csv' with (format csv, header true);

-- клиенты 

copy clients (client_id, first_name, last_name, age, job_id, marital_id,
              education_id, has_credit_default, balance_eur,
              has_housing_loan, has_personal_loan)
    from '/Users/Shared/bank_data/clients.csv' with (format csv, header true);

-- контакты 
-- contact_id не передаём: его выдаёт база.
-- contact_year и contact_date остаются NULL до шага 03.
copy contacts (client_id, channel_id, contact_day, contact_month,
               duration_sec, contacts_count, subscribed)
    from '/Users/Shared/bank_data/contacts.csv' with (format csv, header true);

-- история прошлой кампании 
-- Только 8 257 клиентов с реальной историей: у остальных строки нет.
copy previous_campaign (client_id, days_since_prev, contacts_before, outcome_id)
    from '/Users/Shared/bank_data/previous_campaign.csv' with (format csv, header true);

commit;

-- Собрать статистику, иначе планировщик будет ошибаться в оценках
analyze;

-- контрольная сверка 
-- Ожидается: clients 45211 | contacts 45211 | previous_campaign 8257 | jobs 12
select 'clients'           as table_name, count(*) as rows from clients
union all select 'contacts',           count(*) from contacts
union all select 'previous_campaign',  count(*) from previous_campaign
union all select 'jobs',               count(*) from jobs
union all select 'marital_statuses',   count(*) from marital_statuses
union all select 'education_levels',   count(*) from education_levels
union all select 'contact_channels',   count(*) from contact_channels
union all select 'campaign_outcomes',  count(*) from campaign_outcomes
order by 1;
