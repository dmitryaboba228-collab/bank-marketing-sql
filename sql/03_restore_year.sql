--  Восстановление года контакта
--  Выполнять один раз после 02_load.sql. Повторный прогон безопасен:
--  contact_month не меняется, значит результат тот же.

begin;

with steps as (
    select contact_id,
           contact_month,
           case when contact_month < lag(contact_month) over (order by contact_id)
                then 1 else 0 end as year_inc
    from contacts
),
years as (
    select contact_id,
           2008 + sum(year_inc) over (order by contact_id) as y
    from steps
)
update contacts c
set contact_year = years.y,
    contact_date = make_date(years.y::int, c.contact_month::int, c.contact_day::int)
from years
where c.contact_id = years.contact_id;

commit;

-- сверка 
-- ожидается: 45211 | 0 | 2008-05-05 | 2010-11-17 | 30
select count(*)                                   as vsego,
       count(*) filter (where contact_year is null) as bez_goda,
       min(contact_date)                          as pervyy_kontakt,
       max(contact_date)                          as posledniy_kontakt,
       count(distinct (contact_year, contact_month)) as mesyacev
from contacts;

-- Месяцев 30: за сентябрь 2008 данных нет, после августа сразу октябрь.
