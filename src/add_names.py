#!/usr/bin/env python3
"""
Добавляет id и создает португальские имена в UCI Bank Marketing.
Исходные 17 колонок не меняются.
"""
import csv, random, sys

seed = 42

male = """João José António Manuel Francisco Carlos Pedro Miguel Luís Paulo Ricardo
Bruno Rui Nuno Tiago André Hugo Sérgio Vítor Fernando Jorge Marco Daniel Diogo
Rafael Gonçalo Duarte Filipe Alexandre Eduardo Henrique Joaquim Álvaro Artur
Bernardo César Cristiano Dinis Domingos Emanuel Fábio Gabriel Gil Gustavo Hélder
Ivo Jaime Leonardo Lourenço Mário Martim Mateus Nelson Octávio Osvaldo Raul
Renato Rodrigo Salvador Samuel Simão Telmo Tomás Vasco Xavier Afonso Armando
Benjamim Custódio Elias Ernesto Estêvão Fausto Firmino Gaspar Horácio Isidro
Júlio Leandro Lino Lucas Marcelo Matias Norberto Patrício Reinaldo Roberto Rúben
Sebastião Teodoro Valentim Valter Vicente Virgílio Wilson Zacarias""".split()

female = """Maria Ana Sofia Beatriz Catarina Inês Joana Mariana Rita Sara Carolina
Cláudia Cristina Daniela Diana Filipa Helena Isabel Leonor Luísa Madalena
Margarida Marta Matilde Patrícia Paula Raquel Rosa Susana Teresa Vera Alice
Adriana Alexandra Amália Andreia Ângela Bárbara Bruna Camila Carla Célia
Constança Dulce Elsa Emília Eduarda Fátima Fernanda Francisca Gabriela Glória
Graça Guilhermina Iolanda Irene Íris Jacinta Júlia Lara Laura Letícia Lídia
Liliana Lúcia Manuela Márcia Mafalda Micaela Mónica Natália Nádia Neusa Olga
Ondina Paulina Regina Renata Rosália Salomé Sandra Sílvia Silvana Solange Tânia
Telma Vanessa Verónica Vitória Zélia Benedita Clara Débora Eva""".split()

surnames = """Silva Santos Ferreira Pereira Oliveira Costa Rodrigues Martins Jesus
Sousa Fernandes Gonçalves Gomes Lopes Marques Alves Almeida Ribeiro Pinto
Carvalho Teixeira Moreira Correia Mendes Nunes Soares Vieira Monteiro Cardoso
Rocha Raposo Neves Coelho Cruz Cunha Pires Ramos Reis Simões Antunes Matos
Fonseca Machado Araújo Barbosa Tavares Castro Campos Amaral Baptista Barros
Borges Branco Brito Cabral Caetano Camacho Cordeiro Domingues Duarte Esteves
Faria Figueiredo Freitas Garcia Guerreiro Henriques Leal Leite Lima Lourenço
Macedo Magalhães Maia Melo Miranda Morais Mota Nogueira Paiva Pacheco Pinheiro
Queirós Rebelo Resende Salgado Sampaio Serra Torres Valente Vaz Ventura Xavier
Abreu Aguiar Andrade Azevedo Bastos Bernardes Botelho Bento""".split()

given = male + female
numeric = {"id", "age", "balance", "day", "duration", "campaign", "pdays", "previous"}


def fmt(col, val):
    return val if col in numeric else '"%s"' % val


def main(src, dst):
    rnd = random.Random(seed)
    with open(src, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f, delimiter=";", quotechar='"'))

    header = ["id", "first_name", "last_name"] + rows[0]
    out = [header]

    for i, row in enumerate(rows[1:], start=1):
        first = rnd.choice(given)
        s1 = rnd.choice(surnames)
        s2 = rnd.choice(surnames)
        while s2 == s1:                      # два разных родовых имени
            s2 = rnd.choice(surnames)
        out.append([str(i), first, "%s %s" % (s1, s2)] + row)

    with open(dst, "w", encoding="utf-8", newline="") as f:
        for row in out:
            f.write(";".join(fmt(c, v) for c, v in zip(header, row)) + "\n")

    names = ["%s %s" % (r[1], r[2]) for r in out[1:]]
    print("строк:", len(out) - 1)
    print("колонок:", len(header))
    print("уникальных ФИО:", len(set(names)))
    print("повторов ФИО:", len(names) - len(set(names)))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
