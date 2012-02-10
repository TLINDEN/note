CREATE TABLE note (
  id int(10) DEFAULT '0' NOT NULL auto_increment,
  number int(10),
  firstline text,
  note text,
  date text,
  PRIMARY KEY (id)
);
