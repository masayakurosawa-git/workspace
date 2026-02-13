create table employees (
    id              integer     PRIMARY KEY,
    name            text        NOT NULL,
    age             integer,
    gender          text, 
    department_id   integer
);

create table departments (
    id      integer     PRIMARY KEY,
    name    text	    NOT NULL
);