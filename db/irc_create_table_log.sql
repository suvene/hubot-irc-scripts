create table log2 (
    id int unsigned auto_increment not null,
    event_time timestamp not null default now(),    # the field that defaults to "now"
    channel varchar(100) default null,
    command varchar(100) default null,
    nick varchar(100) default null,
    message varchar(21000) default null,
    mecab text default null,
    ngram text default null,
    FULLTEXT (channel, nick, message),
    FULLTEXT (mecab),
    FULLTEXT (ngram),
    primary key(id),
    KEY `log_ix1` (`event_time`)
) ENGINE=InnoDB default charset utf8
collate utf8_unicode_ci;
