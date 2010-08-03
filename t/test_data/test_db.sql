-- so we can test simple foreign key references
DROP TABLE IF EXISTS avt_ref_table;
CREATE TABLE avt_ref_table (
	id int unsigned not null primary key,
	name varchar(64)
);

INSERT INTO avt_ref_table VALUES (1,'First Value');
INSERT INTO avt_ref_table VALUES (2,'Second Value');
INSERT INTO avt_ref_table VALUES (3,'Third Value');
INSERT INTO avt_ref_table VALUES (4,'Fourth Value');


-- so we can test many to many relationships
DROP TABLE IF EXISTS avt_xref_table;
CREATE TABLE avt_xref_table (
	avt_table_id int unsigned not null,
	avt_ref_table_id int unsigned not null
);

INSERT INTO avt_xref_table VALUES (1,1);
INSERT INTO avt_xref_table VALUES (2,1);
INSERT INTO avt_xref_table VALUES (2,2);
INSERT INTO avt_xref_table VALUES (3,1);
INSERT INTO avt_xref_table VALUES (3,2);
INSERT INTO avt_xref_table VALUES (3,3);

INSERT INTO avt_table VALUES(1,1,0,'2009-01-01','13:00:00','2000-02-01 12:00:00','a text string',             'a much larger text string');
INSERT INTO avt_table VALUES(2,2,1,'2010-01-01','17:00:00','2010-02-01 14:00:00','another text string',       'different much longer string');
INSERT INTO avt_table VALUES(3,4,1,'2010-03-15','16:00:00','2010-01-01 12:00:00','loren ipsum solor sit amet','consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.');

DROP TABLE IF EXISTS avt_all_types;
CREATE TABLE avt_all_types (
	id int unsigned not null primary key,
	bigint_not_null             bigint not null,
	bigint_null                 bigint     null,
	bigint_unsigned_not_null    bigint unsigned not null,
	bigint_unsigned_null        bigint unsigned     null,
	char_not_null               char(32) not null,
	char_null                   char(32)     null,
	date_not_null               date not null,
	date_null                   date     null,
	decimal_not_null            decimal(4,2) not null,
	decimal_null                decimal(4,2)     null,
	int_not_null                int not null,
	int_null                    int     null,
	int_unsigned_not_null       int unsigned not null,
	int_unsigned_null           int unsigned     null,
	integer_not_null            integer not null,
	integer_null                integer     null,
	mediumint_not_null          mediumint not null,
	mediumint_null              mediumint     null,
	mediumint_unsigned_not_null mediumint unsigned not null,
	mediumint_unsigned_null     mediumint unsigned null,
	smallint_not_null           smallint not null,
	smallint_null               smallint     null,
	smallint_unsigned_not_null  smallint unsigned not null,
	smallint_unsigned_null      smallint unsigned     null,
	text_not_null               text not null,
	text_null                   text     null,
	time_not_null               time not null,
	time_null                   time     null,
	tinyint_not_null            tinyint not null,
	tinyint_null                tinyint     null,
	tinyint_unsigned_not_null   tinyint unsigned not null,
	tinyint_unsigned_null       tinyint unsigned     null,
	varchar_not_null            varchar(64) not null,
	varchar_null                varchar(64)     null
);
