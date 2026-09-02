#!/usr/bin/env python3
"""
ETL: плоский bank-full-named.csv  ->  нормализованные CSV под COPY в PostgreSQL.
Год контакта НЕ восстанавливается - это отдельная задача.

"""
import csv
import os
import sys

src = "raw/bank-full-named.csv"
out = "data"

months = {"jan": 1, "feb": 2, "mar": 3, "apr": 4,  "may": 5,  "jun": 6,
          "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12}

#Справочники:

dicts = [
    ("jobs",              "job",       "job_id",       "job_name"),
    ("marital_statuses",  "marital",   "marital_id",   "status_name"),
    ("education_levels",  "education", "education_id", "level_name"),
    ("contact_channels",  "contact",   "channel_id",   "channel_name"),
    ("campaign_outcomes", "poutcome",  "outcome_id",   "outcome_name"),
]

no_history = -1          # pdays = -1 означает нет истории контактов


def write(name, header, rows):
    path = os.path.join(out, name + ".csv")
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print("  %-22s %7d строк" % (name + ".csv", len(rows)))
    return len(rows)


def yn(value):
    if value not in ("yes", "no"):
        raise ValueError("ожидалось yes/no, получено %r" % value)
    return "true" if value == "yes" else "false"


def main():
    if not os.path.exists(src):
        sys.exit("не найден %s - запускай из корня проекта" % src)
    os.makedirs(out, exist_ok=True)

    with open(src, encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f, delimiter=";"))
    print("прочитано %d строк из %s\n" % (len(rows), src))

    # справочники 
    print("справочники:")
    lookup = {}
    for name, col, id_col, val_col in dicts:
        values = sorted({r[col] for r in rows})
        lookup[col] = {v: i for i, v in enumerate(values, start=1)}
        write(name, [id_col, val_col], [(i, v) for v, i in lookup[col].items()])

    # clients
    print("\nосновные таблицы:")
    clients = [
        (
            r["id"],
            r["first_name"],
            r["last_name"],
            r["age"],
            lookup["job"][r["job"]],
            lookup["marital"][r["marital"]],
            lookup["education"][r["education"]],
            yn(r["default"]),
            r["balance"],
            yn(r["housing"]),
            yn(r["loan"]),
        )
        for r in rows
    ]
    n_clients = write("clients", [
        "client_id", "first_name", "last_name", "age", "job_id", "marital_id",
        "education_id", "has_credit_default", "balance_eur",
        "has_housing_loan", "has_personal_loan",
    ], clients)

    # contacts
    # contact_id выдаёт IDENTITY.
    # contact_year и contact_date остаются NULL и потом заполняются отдельным шагом.
    contacts = [
        (
            r["id"],
            lookup["contact"][r["contact"]],
            r["day"],
            months[r["month"]],
            r["duration"],
            r["campaign"],
            yn(r["y"]),
        )
        for r in rows
    ]
    n_contacts = write("contacts", [
        "client_id", "channel_id", "contact_day", "contact_month",
        "duration_sec", "contacts_count", "subscribed",
    ], contacts)

    # previous_campaign 
    # Только клиенты с реальной историей (-1/0/unknown не хранятся и выражают отсутствие строки):
    prev, skipped = [], 0
    for r in rows:
        if int(r["pdays"]) == no_history:
            skipped += 1
            continue
        prev.append((r["id"], r["pdays"], r["previous"],
                     lookup["poutcome"][r["poutcome"]]))
    n_prev = write("previous_campaign", [
        "client_id", "days_since_prev", "contacts_before", "outcome_id",
    ], prev)

    # сверка
    print("\nсверка:")
    print("  без истории (строка не создана): %d" % skipped)
    anomalies = sum(1 for r in rows
                    if int(r["pdays"]) != no_history and r["poutcome"] == "unknown")
    print("  аномалий 'история есть, исход unknown': %d  <- задача 02" % anomalies)

    ok = (n_clients == len(rows) and n_contacts == len(rows)
          and n_prev + skipped == len(rows))
    print("\n%s" % ("контрольные суммы сошлись" if ok else "РАСХОЖДЕНИЕ В СУММАХ"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
