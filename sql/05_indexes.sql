--  Индексы и замеры
--  Цель - проверить, дают ли они выигрыш на этом объёме.
--  Порядок: сначала замер ДО, потом создание, потом замер ПОСЛЕ.


-- 1. Замеры ДО 
-- соединение с справочником и группировка (запрос 9)

explain (analyze, buffers)
select j.job_name, count(*)
from clients as c
join jobs as j on j.job_id = c.job_id
group by j.job_name;

-- сортировка по балансу (запрос 5)

explain (analyze, buffers)
select client_id, balance_eur
from clients
order by balance_eur desc
limit 20;

-- выборка по диапазону возраста (часть запроса 7)

explain (analyze, buffers)
select count(*)
from clients
where age between 30 and 45;


-- 2. Создание индексов 
-- PostgreSQL создаёт индексы для первичных ключей поэтому индексируем
-- столбцы-ссылки, по которым идут соединения.

create index if not exists idx_clients_job       on clients (job_id);
create index if not exists idx_clients_education on clients (education_id);
create index if not exists idx_clients_marital   on clients (marital_id);
create index if not exists idx_contacts_channel  on contacts (channel_id);
create index if not exists idx_prev_outcome      on previous_campaign (outcome_id);

-- Для сортировок и диапазонных условий.

create index if not exists idx_clients_balance   on clients (balance_eur);
create index if not exists idx_clients_age       on clients (age);
create index if not exists idx_contacts_attempts on contacts (contacts_count);

analyze;


-- 3. Замеры ПОСЛЕ 
-- Те же три запроса, сравниваем Execution Time 

explain (analyze, buffers)
select j.job_name, count(*)
from clients as c
join jobs as j on j.job_id = c.job_id
group by j.job_name;

explain (analyze, buffers)
select client_id, balance_eur
from clients
order by balance_eur desc
limit 20;

explain (analyze, buffers)
select count(*)
from clients
where age between 30 and 45;


-- 4. Что реально используется
-- idx_scan показывает, сколько раз индекс пригодился планировщику.

select indexrelname as index_name,
       idx_scan     as ispolzovan_raz,
       pg_size_pretty(pg_relation_size(indexrelid)) as razmer
from pg_stat_user_indexes
where schemaname = 'public'
order by idx_scan, indexrelname;


-- 5. Итог
-- Если замеры показали, что выигрыша нет, индексы стоит убрать: каждый занимает место и замедляет вставку.

