-- name: ddl-mysql-01-collection-scripts!
create table db.collection_mysql_config (
  pkey varchar(256),
  dma_source_id varchar(256),
  dma_manual_id varchar(256),
  variable_category varchar(256),
  variable_name varchar(256),
  variable_value mediumtext
);

create table db.collection_mysql_data_types (
  pkey varchar(256),
  dma_source_id varchar(256),
  dma_manual_id varchar(256),
  variable_category varchar(256),
  variable_name varchar(256),
  variable_value mediumtext
);
