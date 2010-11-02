DROP TABLE IF EXISTS avt_table;
CREATE TABLE avt_table (
    id integer primary key autoincrement,
	avt_ref_table_id int unsigned not null,
	a_bit  bit,
	a_date date,
	a_time time,
	a_datetime datetime,
	a_varchar varchar(128),
	a_unique varchar(16) UNIQUE,
	a_text text
);
