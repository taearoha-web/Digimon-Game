import {DatabaseSync} from 'node:sqlite';
import {readFileSync, readdirSync} from 'node:fs';

const DRIZZLE = new URL('../drizzle/', import.meta.url);

/** Executes the production prepared SQL against SQLite, including atomic batch.
 * No query recognition / hand-written save behavior can hide CAS bugs here.
 * Without an argument every migration in drizzle/ is applied in order (as
 * `wrangler d1 migrations apply` does); with one, only that file. */
export class D1Sqlite {
  constructor(migration = null) {
    this.sqlite = new DatabaseSync(':memory:');
    const files = migration ? [migration]
      : readdirSync(DRIZZLE).filter(name => name.endsWith('.sql')).sort().map(name => new URL(name, DRIZZLE));
    for (const file of files) this.sqlite.exec(readFileSync(file, 'utf8'));
  }

  prepare(sql) { return new D1Statement(this, sql); }

  async batch(statements) {
    this.sqlite.exec('BEGIN IMMEDIATE');
    try {
      const results = statements.map(statement => statement.execute());
      this.sqlite.exec('COMMIT');
      return results;
    } catch (error) {
      this.sqlite.exec('ROLLBACK');
      throw error;
    }
  }

  close() {this.sqlite.close();}
}

class D1Statement {
  constructor(database, sql, args = []) {this.database = database; this.sql = sql; this.args = args;}
  bind(...args) {return new D1Statement(this.database, this.sql, args);}
  execute() {
    const statement = this.database.sqlite.prepare(this.sql);
    const results = statement.columns().length ? statement.all(...this.args).map(row => ({...row})) : [];
    const run = statement.columns().length ? null : statement.run(...this.args);
    const changes = run?.changes ?? this.database.sqlite.prepare('SELECT changes() AS n').get().n;
    return {success: true, results, meta: {changes, last_row_id: run?.lastInsertRowid ?? 0}};
  }
  async first(column) {const row = this.execute().results[0] ?? null; return column ? row?.[column] ?? null : row;}
  async all() {return this.execute();}
  async run() {return this.execute();}
}
