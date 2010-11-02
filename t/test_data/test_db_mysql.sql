DROP TABLE IF EXISTS avt_table;
CREATE TABLE avt_table (
    id int unsigned not null primary key auto_increment,
	avt_ref_table_id int unsigned not null,
	a_bit  bit,
	a_date date,
	a_time time,
	a_datetime datetime,
	a_varchar varchar(128),
	a_unique varchar(16),
	a_text text,
	UNIQUE INDEX a_unique(a_unique)
);
