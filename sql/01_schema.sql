--  Схема БД: телемаркетинг банка (UCI Bank Marketing)
--  Порядок таблиц важен: справочники создаются раньше тех, кто на них ссылается.

drop table if exists previous_campaign, contacts, clients,
    jobs, marital_statuses, education_levels,
    contact_channels, campaign_outcomes cascade;

--  СПРАВОЧНИКИ
--  Вынесены отдельно, чтобы значение вне списка не прошло по внешнему ключу: опечатка становится невозможной.

create table jobs (
    job_id    smallint     primary key,
    job_name  varchar(15)  not null unique
);

create table marital_statuses (
    marital_id   smallint     primary key,
    status_name  varchar(10)  not null unique
);

create table education_levels (
    education_id  smallint     primary key,
    level_name    varchar(10)  not null unique
);

create table contact_channels (
    channel_id    smallint     primary key,
    channel_name  varchar(10)  not null unique
);

create table campaign_outcomes (
    outcome_id    smallint     primary key,
    outcome_name  varchar(10)  not null unique
);

--  КЛИЕНТЫ - 45 211 строк
--  client_id объявлен обычным integer, а не IDENTITY: номера приходят из файла, база их не выдаёт.

create table clients (
    client_id           integer      primary key,
    first_name          varchar(30)  not null,
    last_name           varchar(60)  not null,
    age                 smallint     not null check (age between 18 and 120),
    job_id              smallint     not null references jobs,
    marital_id          smallint     not null references marital_statuses,
    education_id        smallint     not null references education_levels,
    has_credit_default  boolean      not null,
    balance_eur         integer      not null,
    has_housing_loan    boolean      not null,
    has_personal_loan   boolean      not null
);

--  КОНТАКТЫ ТЕКУЩЕЙ КАМПАНИИ - 45 211 строк
--  Связь с клиентом 1:1 (UNIQUE): в данных на клиента ровно один итог кампании. Появится вторая кампания - достаточно снять UNIQUE, и связь станет 1:N.
--  contact_year и contact_date заполняются позже, отдельным
--  шагом

create table contacts (
    contact_id      integer   generated always as identity primary key,
    client_id       integer   not null unique references clients on delete cascade,
    channel_id      smallint  not null references contact_channels,
    contact_day     smallint  not null check (contact_day between 1 and 31),
    contact_month   smallint  not null check (contact_month between 1 and 12),
    contact_year    smallint,
    contact_date    date,
    duration_sec    integer   not null check (duration_sec >= 0),
    contacts_count  smallint  not null check (contacts_count >= 1),
    subscribed      boolean   not null
);

--  ИСТОРИЯ ПРОШЛОЙ КАМПАНИИ - 8 257 строк
--  Только клиенты, которых реально контактировали раньше.
--  У остальных 36 954 строки здесь нет: в исходнике это были заглушки -1 / 0 / unknown.

create table previous_campaign (
    client_id        integer   primary key references clients on delete cascade,
    days_since_prev  smallint  not null check (days_since_prev > 0),
    contacts_before  smallint  not null check (contacts_before > 0),
    outcome_id       smallint  not null references campaign_outcomes
);

--Пояснения колонок

comment on column clients.balance_eur is
    'Средний годовой остаток, евро. Бывает отрицательным: овердрафт.';
comment on column contacts.duration_sec is
    'Длительность звонка. УТЕЧКА ЦЕЛЕВОЙ: известна только после звонка, в предсказании не использовать.';
comment on column contacts.contacts_count is
    'Сколько раз звонили этому клиенту в текущей кампании.';
comment on column contacts.subscribed is
    'Целевая переменная: открыл срочный вклад или нет.';
comment on column contacts.contact_year is
    'Пусто после загрузки. Восстанавливается из порядка строк, см. 03_restore_year.sql.';
comment on column previous_campaign.days_since_prev is
    'Дней с последнего контакта в прошлой кампании.';
