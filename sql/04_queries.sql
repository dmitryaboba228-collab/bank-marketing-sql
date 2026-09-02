--  30 аналитических запросов
--  Выполнять после 01_schema.sql, 02_load.sql, 03_restore_year.sql
--
--  Блок 0  (1-4)   качество данных
--  Блок 1  (5-8)   первое знакомство
--  Блок 2  (9-14)  агрегация
--  Блок 3  (15-19) соединения и витрина
--  Блок 4  (20-24) подзапросы и сценарии
--  Блок 5  (25-30) оконные функции


--  БЛОК 0. Качество данных:

-- 1. Сверка объёмов загрузки
--    Выведет: 8 строк - имя таблицы и число строк в ней.
-- clients 45 211, contacts 45 211, previous_campaign 8 257, jobs 12, marital_statuses 3, education_levels 4, contact_channels 3, campaign_outcomes 4

select 'clients' as table_name, count(*) as rows from clients
union all select 'contacts', count(*) from contacts
union all select 'previous_campaign', count(*) from previous_campaign
union all select 'jobs', count(*) from jobs
union all select 'marital_statuses', count(*) from marital_statuses
union all select 'education_levels', count(*) from education_levels
union all select 'contact_channels', count(*) from contact_channels
union all select 'campaign_outcomes', count(*) from campaign_outcomes
order by 1;


-- 2. Пять аномалий
--    Выведет: 5 строк - client_id, дней с прошлого контакта, число контактов, название исхода.

select p.client_id,
p.days_since_prev,
p.contacts_before,
o.outcome_name
from previous_campaign p
join campaign_outcomes o on p.outcome_id = o.outcome_id
where o.outcome_name = 'unknown';


-- 3. Ссылочная целостность
--    Выведет: 2 строки с метками проверок, в обеих 0.

select 'contacts без клиента' as check_name, count(*) as con
from contacts ct
left join clients c on ct.client_id = c.client_id
where c.client_id is null
union all
select 'previous_campaign без клиента', count(*)
from previous_campaign pc
left join clients c on pc.client_id = c.client_id
where c.client_id is null;


-- 4. Границы числовых колонок
--    Выведет: age 18...95, balance -8 019...102 127, duration 0...4 918, contacts_count 1...63, days_since_prev 1...871, contacts_before 1...275

select *
from (select min(age) as mia, max(age) as maa,
min(balance_eur) as mib, max(balance_eur) as mab
from clients),
(select min(duration_sec) as mid, max(duration_sec) as mad,
min(contacts_count) as micc, max(contacts_count) as macc
from contacts),
(select min(days_since_prev) as midsp, max(days_since_prev) as madsp,
min(contacts_before) as micb, max(contacts_before) as macb
from previous_campaign);


--  БЛОК 1. Первое знакомство:

-- 5. Двадцать самых состоятельных
--    Выведет: 20 строк - id, имя, фамилия, профессия, баланс. В первой строке баланс 102 127 - максимум по всей базе.

select c.client_id, c.first_name, c.last_name, j.job_name, c.balance_eur
from clients as c
join jobs as j on j.job_id = c.job_id
order by c.balance_eur desc
limit 20;


-- 6. Клиенты в минусе
--    Выведет: 1 строка - 3 766 клиентов из 45 211, доля 8.33%.

select count(*) filter (where balance_eur < 0) as otr_bal,
count(*) as summa,
round(count(*) filter (where balance_eur < 0) * 100.0 / count(*), 3) as per
from clients;


-- 7. Премиум-сегмент
--    Выведет: 1 строка - размер сегмента, согласия, конверсия сегмента и общая по базе. 345 клиентов, конверсия 23.77% против базовых 11.70%.

select count(*) as rich,
sum(case when con.subscribed then 1 else 0 end) as subs,
round(sum(case when con.subscribed then 1 else 0 end) * 100.0
/ count(*), 2) as per,
(select round(sum(case when subscribed then 1 else 0 end) * 100.0
/ count(*), 2) from contacts) as sred
from clients c
join education_levels j on j.education_id = c.education_id
join contacts con on con.client_id = c.client_id
where c.age between 30 and 45
and j.level_name = 'tertiary'
and c.has_housing_loan = false
and c.has_personal_loan = false
and c.balance_eur > 5000;


-- 8. Звонки нулевой длительности
--    Выведет: 3 строки, у всех subscribed = false.

select client_id, duration_sec, contacts_count, subscribed
from contacts
where duration_sec = 0;


--  БЛОК 2. Агрегация:

-- 9. Конверсия по профессиям
--    Выведет: 12 строк - профессия, клиентов, согласий, конверсия %.

select c.job_id, job_name,
count(job_name) as kol,
count(case when subscribed then 1 end) as sumsub,
round(count(case when subscribed then 1 end) * 100.0 / count(*), 2) as per
from clients as c
join jobs as j on j.job_id = c.job_id
join contacts as con on c.client_id = con.client_id
group by c.job_id, job_name
order by per desc;


-- 10. Среднее против медианы
--    Выведет: По строке на каждую крупную профессию - клиентов, среднее, медиана.

select c.job_id, job_name,
count(*) as kol,
round(avg(balance_eur)) as average,
round(percentile_cont(0.5) within group (order by balance_eur)::numeric) as mediana
from clients as c
join jobs as j on j.job_id = c.job_id
group by c.job_id, job_name
having count(*) > 500
order by average desc;


-- 11. Конверсия по месяцу года
--    Выведет: 12 строк - месяц, звонков, согласий, конверсия %.

select contact_month,
count(*) as calls,
count(case when subscribed then 1 end) as subs,
round(count(case when subscribed then 1 end) * 100.0 / count(*), 2) as per
from contacts
group by contact_month
order by per desc;


-- 12. Куда ушло время разговоров
--    Выведет: 2 строки. false - 39 922 звонка и 2 453 часа, true - 5 289 и 789 часов.

select subscribed,
count(*) as q,
sum(duration_sec) as summa,
round(sum(duration_sec) / 3600.0) as chasov
from contacts
group by subscribed;


-- 13. Конверсия по каналу связи
--    Выведет: 3 строки. cellular 29 285 / 14.92% - telephone 2 906 / 13.42% - unknown 13 020 / 4.07%.

select cc.channel_name as cn,
count(*) as calls,
sum(case when c.subscribed then 1 else 0 end) as subs,
round(sum(case when c.subscribed then 1 else 0 end) * 100.0 / count(*), 2) as per
from contacts as c
join contact_channels as cc on c.channel_id = cc.channel_id
group by cc.channel_name
order by per desc;


-- 14. Образование в разрезе семейного положения
--    Выведет: 20 строк: 12 клеток + 4 итога по образованию + 3 по статусу + 1 общий.

select case when grouping(e.level_name) = 1 then 'ВСЕ ОБРАЗОВАНИЯ' else e.level_name end as education,
case when grouping(m.status_name) = 1 then 'ВСЕГО' else m.status_name end as marital,
count(*) as q,
sum(case when con.subscribed then 1 else 0 end) as subs,
round(sum(case when con.subscribed then 1 else 0 end) * 100.0 / count(*), 2) as per
from clients as c
join education_levels as e on e.education_id = c.education_id
join marital_statuses as m on m.marital_id = c.marital_id
join contacts as con on con.client_id = c.client_id
group by cube (e.level_name, m.status_name)
order by grouping(e.level_name), e.level_name,
grouping(m.status_name), m.status_name;


--  БЛОК 3. Соединения и витрина:

-- 15. С историей контактов и без неё
--    Выведет: 2 строки. С историей 8 257 клиентов и 23.07%, без истории 36 954 и 9.16%.

select case when p.client_id is null then 'без истории' else 'с историей' end as segment,
count(*) as clients,
sum(case when c.subscribed then 1 else 0 end) as subs,
round(sum(case when c.subscribed then 1 else 0 end) * 100.0 / count(*), 2) as per
from clients as cl
join contacts as c on cl.client_id = c.client_id
left join previous_campaign as p on cl.client_id = p.client_id
group by 1
order by per desc;


-- 16. Эхо прошлой кампании
--    Выведет: 3-4 строки. success 1 511 - failure 4 901 - other 1 840 - unknown 5.

select outcome_name,
count(*) as q,
sum(case when c.subscribed then 1 else 0 end) as subs,
round(sum(case when c.subscribed then 1 else 0 end) * 100.0 / count(*), 2) as per
from previous_campaign as pc
join campaign_outcomes as co on co.outcome_id = pc.outcome_id
join contacts as c on c.client_id = pc.client_id
group by 1
order by per desc;


-- 17. Потерянные клиенты
--    Выведет: 1 строка - количество, средний возраст, средний баланс.

select count(*),
round(avg(cl.age), 1) as avg_age,
round(avg(cl.balance_eur)) as avg_balance
from previous_campaign as pc
inner join contacts as c on c.client_id = pc.client_id
inner join clients as cl on cl.client_id = pc.client_id
inner join campaign_outcomes as co on co.outcome_id = pc.outcome_id
where outcome_name = 'success'
and subscribed = false;


-- 18. Антиджойн двумя способами
--    Выведет: Оба запроса дают 36 954 - клиентов, которых раньше не набирали.

explain (analyze, buffers)
select count(*)
from clients as cl
left join previous_campaign as pc on pc.client_id = cl.client_id
where pc.client_id is null;

explain (analyze, buffers)
select count(*)
from clients as cl
where not exists (select 1
from previous_campaign as pc
where pc.client_id = cl.client_id);


-- 19. Витрина: клиент одной строкой
--    Выведет: Представление на 45 211 строк. Контрольный select в конце обязан дать это число.

drop view if exists client_view;

create view client_view as
select cl.client_id, cl.first_name, cl.last_name, cl.age,
j.job_name,
ms.status_name as marital_status,
el.level_name as education,
cl.has_credit_default,
cl.balance_eur,
cl.has_housing_loan,
cl.has_personal_loan,
ch.channel_name as contact_channel,
c.contact_day, c.contact_month, c.contact_year, c.contact_date,
c.duration_sec, c.contacts_count, c.subscribed,
(pc.client_id is not null) as had_history,
pc.days_since_prev, pc.contacts_before,
coalesce(co.outcome_name, 'no_history') as prev_outcome
from clients as cl
join jobs as j on cl.job_id = j.job_id
join marital_statuses as ms on cl.marital_id = ms.marital_id
join education_levels as el on cl.education_id = el.education_id
join contacts as c on cl.client_id = c.client_id
join contact_channels as ch on c.channel_id = ch.channel_id
left join previous_campaign as pc on cl.client_id = pc.client_id
left join campaign_outcomes as co on pc.outcome_id = co.outcome_id;

-- контроль: обязано быть 45211

select count(*) as rows_in_view from client_view;


--  БЛОК 4. Подзапросы и сценарии:

-- 20. Клиенты с балансом выше среднего по профессии
--    Выведет: Оба дают 11 872 строки.
--             Время различается: соединение около 12 мс, коррелированный подзапрос около 57 000 мс.

explain (analyze, buffers)
select client_id, first_name, last_name, balance_eur, job_name
from clients
join (select cl.job_id as jobb, avg(balance_eur) as avg_balance, job_name
from clients as cl
join jobs as j on cl.job_id = j.job_id
group by cl.job_id, job_name) as t on jobb = job_id
where balance_eur > avg_balance;

explain (analyze, buffers)
select client_id, first_name, last_name, balance_eur, job_id
from clients as cl
where balance_eur > (select avg(c.balance_eur)
from clients as c
where c.job_id = cl.job_id);


-- 21. Вклад профессий в общий результат
--    Выведет: 12 строк - профессия, клиентов, согласий, конверсия, доля, накопительно.

with by_job as (
select j.job_name,
count(*) as q,
sum(case when c.subscribed then 1 else 0 end) as subs
from clients as cl
join jobs as j on cl.job_id = j.job_id
join contacts as c on cl.client_id = c.client_id
group by j.job_name
)
select job_name,
q,
subs,
round(subs * 100.0 / q, 2) as per,
round(subs * 100.0 / sum(subs) over (), 2) as share_per,
round(sum(subs) over (order by subs desc
rows between unbounded preceding and current row)
* 100.0 / sum(subs) over (), 2) as cumulative_per
from by_job
order by subs desc;


-- 22. Возрастные когорты
--    Выведет: 6 строк, сумма клиентов 45 211: 18-25 - 23.95%, минимум 46-55 - 9.35%, максимум 65+ - 42.61%.

with age_rank as (
select case when age <= 25 then '18-25'
when age <= 35 then '26-35'
when age <= 45 then '36-45'
when age <= 55 then '46-55'
when age <= 65 then '56-65'
else '65+' end as age_group,
count(*) as q,
sum(case when c.subscribed then 1 else 0 end) as subs
from clients as cl
join contacts as c on c.client_id = cl.client_id
group by 1
)
select age_group,
q,
subs,
round(subs * 100.0 / q, 2) as per
from age_rank
order by age_group;


-- 23. Золотой сегмент
--    Выведет: 12 строк. У всех конверсия выше 11.70% и клиентов больше 300.

with total as (
select j.job_name,
el.level_name,
case when age <= 25 then '18-25'
when age <= 35 then '26-35'
when age <= 45 then '36-45'
when age <= 55 then '46-55'
when age <= 65 then '56-65'
else '65+' end as age_group,
count(*) as q,
sum(case when c.subscribed then 1 else 0 end) as subs,
round(sum(case when c.subscribed then 1 else 0 end) * 100.0 / count(*), 2) as per
from clients as cl
join jobs as j on cl.job_id = j.job_id
join education_levels as el on cl.education_id = el.education_id
join contacts as c on cl.client_id = c.client_id
group by j.job_name, el.level_name, age_group
having count(*) > 300
),
avg_conv as (
select sum(case when subscribed then 1 else 0 end) * 100.0 / count(*) as sred
from contacts
)
select job_name, level_name, age_group, q, subs, per,
round(sred, 2) as sred
from total
cross join avg_conv
where per > sred
order by per desc;


-- 24. Цена ограничения обзвона
--    Выведет: 1 строка. Экономия 27 275 звонков - 21.83% всего обзвона.

select sum(contacts_count) as calls,
count(*) as q,
sum(case when subscribed then 1 else 0 end) as subs,
sum(greatest(contacts_count - 4, 0)) as econ,
round(sum(greatest(contacts_count - 4, 0)) * 100.0
/ sum(contacts_count), 2) as econ_per,
sum(case when contacts_count > 4 and subscribed then 1 else 0 end) as lose_subs,
round(sum(case when contacts_count > 4 and subscribed then 1 else 0 end) * 100.0
/ sum(case when subscribed then 1 else 0 end), 2) as lose_per,
round(sum(case when subscribed then 1 else 0 end) * 100.0 / count(*), 2) as past_conv,
round(sum(case when contacts_count <= 4 and subscribed then 1 else 0 end) * 100.0
/ count(*), 2) as new_conv
from contacts;


--  БЛОК 5. Оконные функции:

-- 25. Рейтинг профессий тремя функциями
--    Выведет: 12 строк - конверсия, округлённая конверсия и три колонки рангов.

with by_job as (
select c.job_id, job_name,
count(job_name) as kol,
count(case when subscribed then 1 end) as sumsub,
round(count(case when subscribed then 1 end) * 100.0 / count(*), 2) as per
from clients as c
join jobs as j on j.job_id = c.job_id
join contacts as con on c.client_id = con.client_id
group by c.job_id, job_name
)
select job_id, job_name,
kol,
sumsub,
per,
round(per) as rounded_per,
rank() over (order by round(per) desc) as rank,
dense_rank() over (order by round(per) desc) as dense_rank,
row_number() over (order by round(per) desc) as row_number
from by_job
order by per desc;


-- 26. Топ-3 клиента внутри каждой профессии
--    Выведет: Ровно 36 строк - 12 профессий по три.

with table_1 as (
select job_name, client_id, first_name, last_name, balance_eur,
row_number() over (partition by job_name
order by balance_eur desc) as t
from clients as cl
join jobs as j on j.job_id = cl.job_id
)
select job_name, client_id, first_name, last_name, balance_eur, t
from table_1
where t < 4
order by job_name, t;


-- 27. Нарастающий итог продаж по месяцам
--    Выведет: 30 строк. Последний накопленный итог 5 289 и 100%.

with table_1 as (
select contact_year,
contact_month,
count(*) as q,
sum(case when subscribed then 1 else 0 end) as subs
from contacts
group by contact_year, contact_month
)
select contact_year,
contact_month,
q,
subs,
sum(subs) over (order by contact_year, contact_month
rows between unbounded preceding and current row) as cum,
round(sum(subs) over (order by contact_year, contact_month
rows between unbounded preceding and current row)
* 100.0 / sum(subs) over (), 2) as total
from table_1
order by contact_year, contact_month;


-- 28. Изменение конверсии месяц к месяцу
--    Выведет: 30 строк. В первой изменение пустое - предыдущего месяца нет.

with table_1 as (
select contact_year,
contact_month,
count(*) as q,
sum(case when subscribed then 1 else 0 end) as subs,
round(sum(case when subscribed then 1 else 0 end) * 100.0 / count(*), 2) as per
from contacts
group by contact_year, contact_month
)
select contact_year,
contact_month,
q,
subs,
per,
lag(per) over (order by contact_year, contact_month) as last_month,
round(per - lag(per) over (order by contact_year, contact_month), 2) as diff
from table_1
order by contact_year, contact_month;


-- 29. Децили по балансу счёта
--    Выведет: 10 строк, примерно по 4 521 клиенту.

select d,
count(*) as q,
min(balance) as minimum,
max(balance) as maximum,
sum(case when sub then 1 else 0 end) as subs,
round(sum(case when sub then 1 else 0 end) * 100.0 / count(*), 2) as per
from (
select ntile(10) over (order by cl.balance_eur, cl.client_id) as d,
cl.balance_eur as balance,
c.subscribed as sub
from clients as cl
join contacts as c on c.client_id = cl.client_id
) as t
group by d
order by d;


-- 30. Воронка попыток дозвона
--    Выведет: 6 строк. Конверсия падает с 14.60% до 5.81%, накопительно 48.42% -> 100%,

with table_1 as (
select case when contacts_count >= 6 then 6 else contacts_count end as contacts_count,
count(*) as calls,
sum(case when subscribed then 1 else 0 end) as sub_call
from contacts
group by 1
),
t as (
select contacts_count, calls, sub_call,
round(sub_call * 100.0 / calls, 2) as per_sub_call
from table_1
)
select contacts_count,
calls,
sub_call,
per_sub_call,
sum(sub_call) over w as cum,
round(sum(sub_call) over w * 100.0 / sum(sub_call) over (), 2) as cum_per,
round(first_value(per_sub_call) over (order by contacts_count)
- per_sub_call, 2) as diff
from t
window w as (order by contacts_count rows between unbounded preceding and current row)
order by contacts_count;
