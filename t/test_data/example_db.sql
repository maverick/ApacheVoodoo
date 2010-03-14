DROP TABLE IF EXISTS av_test_parent;
CREATE TABLE av_test_parent (
	id int unsigned not null primary key,
	name varchar(64)
);

DROP TABLE IF EXISTS av_test_types;
CREATE TABLE av_test_types (
	id int unsigned not null auto_increment primary key,
	av_test_parent_id int unsigned not null,

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
	decimal_unsigned_not_null   decimal(4,2) unsigned not null,
	decimal_unsigned_null       decimal(4,2) unsigned     null,
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
