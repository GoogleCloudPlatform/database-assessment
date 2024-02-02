import * as duckdb from "@duckdb/duckdb-wasm"
import duckdb_wasm from "@duckdb/duckdb-wasm/dist/duckdb-mvp.wasm?url"
import mvp_worker from "@duckdb/duckdb-wasm/dist/duckdb-browser-mvp.worker.js?url"
import duckdb_wasm_eh from "@duckdb/duckdb-wasm/dist/duckdb-eh.wasm?url"
import eh_worker from "@duckdb/duckdb-wasm/dist/duckdb-browser-eh.worker.js?url"
import * as arrow from "apache-arrow"
;(async () => {
  try {
    const MANUAL_BUNDLES: duckdb.DuckDBBundles = {
      mvp: {
        mainModule: duckdb_wasm,
        mainWorker: mvp_worker,
      },
      eh: {
        mainModule: duckdb_wasm_eh,
        mainWorker: eh_worker,
      },
    }
    const bundle = await duckdb.selectBundle(MANUAL_BUNDLES)
    const logger = new duckdb.ConsoleLogger()
    const worker = new Worker(bundle.mainWorker!)
    const db = new duckdb.AsyncDuckDB(logger, worker)
    await db.instantiate(bundle.mainModule, bundle.pthreadWorker)

    const conn = await db.connect()
    await conn.query<{ v: arrow.Int }>(
      `SELECT count(*)::INTEGER as v FROM generate_series(0, 100) t(v)`
    )

    await conn.close()
    await db.terminate()
    await worker.terminate()
  } catch (e) {
    console.error(e)
  }
})()
