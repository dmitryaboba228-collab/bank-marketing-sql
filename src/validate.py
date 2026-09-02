#!/usr/bin/env python3
"""
Проверка CSV из data/ перед загрузкой в PostgreSQL.

Применяет те же правила, что и база: первичные и внешние ключи,
ограничения CHECK, диапазоны типов, длины varchar, отсутствие пустых
значений. Плюс несколько смысловых сверок с исходником UCI.

Код возврата 0 - всё чисто, 1 - есть нарушения.
"""
import csv
import os
import sys

fails = []


def load(name):
    with open(os.path.join("data", name + ".csv"), encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def check(cond, msg):
    print(("  OK   " if cond else "  FAIL ") + msg)
    if not cond:
        fails.append(msg)


def main():
    if not os.path.isdir("data"):
        sys.exit("нет каталога data/ - сначала запусти python3 src/etl.py")

    jobs = load("jobs");             mar  = load("marital_statuses")
    edu  = load("education_levels"); ch   = load("contact_channels")
    out  = load("campaign_outcomes")
    cli  = load("clients");          con  = load("contacts")
    prev = load("previous_campaign")

    print("РАЗМЕРЫ")
    check(len(cli) == 45211, "clients = %d" % len(cli))
    check(len(con) == 45211, "contacts = %d" % len(con))
    check(len(prev) == 8257, "previous_campaign = %d" % len(prev))
    check((len(jobs), len(mar), len(edu), len(ch), len(out)) == (12, 3, 4, 3, 4),
          "справочники 12/3/4/3/4")

    print("\nПЕРВИЧНЫЕ КЛЮЧИ")
    ids = [r["client_id"] for r in cli]
    check(len(set(ids)) == len(ids), "clients.client_id уникален")
    check(sorted(map(int, ids)) == list(range(1, 45212)), "client_id = 1..45211 без дыр")
    check(len({r["client_id"] for r in prev}) == len(prev), "previous_campaign.client_id уникален")
    check(len({r["client_id"] for r in con}) == len(con), "contacts.client_id уникален (связь 1:1)")

    print("\nВНЕШНИЕ КЛЮЧИ")
    CL = set(ids)
    for label, rows, col, ref, rcol in (
        ("clients.job_id -> jobs",                          cli,  "job_id",       jobs, "job_id"),
        ("clients.marital_id -> marital_statuses",          cli,  "marital_id",   mar,  "marital_id"),
        ("clients.education_id -> education_levels",        cli,  "education_id", edu,  "education_id"),
        ("contacts.channel_id -> contact_channels",         con,  "channel_id",   ch,   "channel_id"),
        ("previous_campaign.outcome_id -> campaign_outcomes", prev, "outcome_id", out,  "outcome_id"),
    ):
        keys = {r[rcol] for r in ref}
        check(all(r[col] in keys for r in rows), label)
    check(all(r["client_id"] in CL for r in con), "contacts.client_id -> clients")
    check(all(r["client_id"] in CL for r in prev), "previous_campaign.client_id -> clients")

    print("\nОГРАНИЧЕНИЯ CHECK")
    check(all(18 <= int(r["age"]) <= 120 for r in cli), "age BETWEEN 18 AND 120")
    check(all(1 <= int(r["contact_day"]) <= 31 for r in con), "contact_day BETWEEN 1 AND 31")
    check(all(1 <= int(r["contact_month"]) <= 12 for r in con), "contact_month BETWEEN 1 AND 12")
    check(all(int(r["duration_sec"]) >= 0 for r in con), "duration_sec >= 0")
    check(all(int(r["contacts_count"]) >= 1 for r in con), "contacts_count >= 1")
    check(all(int(r["days_since_prev"]) > 0 for r in prev), "days_since_prev > 0")
    check(all(int(r["contacts_before"]) > 0 for r in prev), "contacts_before > 0")

    print("\nТИПЫ, ДЛИНЫ, ПУСТЫЕ ЗНАЧЕНИЯ")
    check(all(-32768 <= int(r["age"]) <= 32767 for r in cli), "age влезает в smallint")
    check(all(-2147483648 <= int(r["balance_eur"]) <= 2147483647 for r in cli),
          "balance_eur влезает в integer")
    check(all(int(r["contacts_count"]) <= 32767 for r in con), "contacts_count влезает в smallint")
    B = {"true", "false"}
    check(all(r[c] in B for r in cli
              for c in ("has_credit_default", "has_housing_loan", "has_personal_loan")),
          "boolean в clients")
    check(all(r["subscribed"] in B for r in con), "boolean в contacts")
    check(max(len(r["first_name"]) for r in cli) <= 30, "first_name <= varchar(30)")
    check(max(len(r["last_name"]) for r in cli) <= 60, "last_name <= varchar(60)")
    check(max(len(r["job_name"]) for r in jobs) <= 15, "job_name <= varchar(15)")
    for nm, rows in (("clients", cli), ("contacts", con), ("previous_campaign", prev)):
        empty = sum(1 for r in rows for v in r.values() if v == "")
        check(empty == 0, "%s: пустых ячеек %d" % (nm, empty))

    print("\nСМЫСЛОВЫЕ СВЕРКИ С ИСХОДНИКОМ")
    check(len(CL) - len(prev) == 36954, "36 954 клиента без истории")
    oname = {r["outcome_id"]: r["outcome_name"] for r in out}
    check(sum(1 for r in prev if oname[r["outcome_id"]] == "unknown") == 5,
          "5 аномалий 'история есть, исход unknown' (задача 02)")
    check(sum(1 for r in con if r["subscribed"] == "true") == 5289, "5 289 согласий")
    zero = [r for r in con if int(r["duration_sec"]) == 0]
    check(len(zero) == 3 and all(r["subscribed"] == "false" for r in zero),
          "3 звонка по 0 секунд, все с отказом (задача 08)")
    check(sum(1 for r in cli if int(r["balance_eur"]) < 0) == 3766,
          "3 766 клиентов в минусе (задача 06)")

    print("\n" + "=" * 52)
    print("ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ" if not fails else "ПРОВАЛЕНО ПРОВЕРОК: %d" % len(fails))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
