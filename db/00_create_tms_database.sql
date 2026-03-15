\set ON_ERROR_STOP on

SELECT 'CREATE DATABASE tms'
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_database
  WHERE datname = 'tms'
)\gexec
