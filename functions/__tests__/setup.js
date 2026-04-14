/**
 * 测试公共脚手架：内存版 Firestore 模拟
 *
 * 设计原则：
 * - 不 mock 自己模块；mock 边界 = firebase-admin
 * - runTransaction(fn) 传入 tx 对象，tx.get/set/update 命中同一 Map
 * - FieldValue.increment / arrayUnion / serverTimestamp 用 sentinel 解引用
 * - 测试文件 require('./setup') 之前就要 jest.mock('firebase-admin', ...)
 */

const INC = Symbol('increment');
const ARR_UNION = Symbol('arrayUnion');
const ARR_REMOVE = Symbol('arrayRemove');
const TS = Symbol('serverTimestamp');

function makeSentinelIncrement(n) {
  return { __sentinel: INC, n };
}
function makeSentinelArrayUnion(items) {
  return { __sentinel: ARR_UNION, items };
}
function makeSentinelArrayRemove(items) {
  return { __sentinel: ARR_REMOVE, items };
}
function makeSentinelServerTimestamp() {
  return { __sentinel: TS };
}

function isSentinel(v) {
  return v && typeof v === 'object' && v.__sentinel !== undefined;
}

function applySentinel(current, sentinel) {
  if (sentinel.__sentinel === INC) {
    return (typeof current === 'number' ? current : 0) + sentinel.n;
  }
  if (sentinel.__sentinel === ARR_UNION) {
    const arr = Array.isArray(current) ? [...current] : [];
    for (const item of sentinel.items) {
      if (!arr.includes(item)) arr.push(item);
    }
    return arr;
  }
  if (sentinel.__sentinel === ARR_REMOVE) {
    const arr = Array.isArray(current) ? [...current] : [];
    return arr.filter(x => !sentinel.items.includes(x));
  }
  if (sentinel.__sentinel === TS) {
    return new Date();
  }
  return current;
}

function mergeUpdate(target, update) {
  const result = { ...target };
  for (const [key, value] of Object.entries(update)) {
    if (isSentinel(value)) {
      result[key] = applySentinel(result[key], value);
    } else if (key.includes('.')) {
      // 点路径嵌套：`acceptedGender.male` → result.acceptedGender.male
      const parts = key.split('.');
      let cur = result;
      for (let i = 0; i < parts.length - 1; i++) {
        cur[parts[i]] = { ...(cur[parts[i]] || {}) };
        cur = cur[parts[i]];
      }
      cur[parts[parts.length - 1]] = isSentinel(value)
        ? applySentinel(cur[parts[parts.length - 1]], value)
        : value;
    } else {
      result[key] = value;
    }
  }
  return result;
}

class FakeDocRef {
  constructor(store, path) {
    this.store = store;
    this.path = path;
    const parts = path.split('/');
    this.id = parts[parts.length - 1];
    this.parent = { id: parts[parts.length - 2] };
  }
  async get() {
    const data = this.store.docs.get(this.path);
    return {
      exists: data !== undefined,
      id: this.id,
      ref: this,
      data: () => (data ? { ...data } : undefined),
    };
  }
  async set(data) {
    this.store.docs.set(this.path, { ...data });
  }
  async update(data) {
    const cur = this.store.docs.get(this.path);
    if (!cur) throw new Error(`update on missing doc ${this.path}`);
    this.store.docs.set(this.path, mergeUpdate(cur, data));
  }
}

class FakeQuery {
  constructor(store, collPath, filters = [], orderBy = null, limit = null) {
    this.store = store;
    this.collPath = collPath;
    this.filters = filters;
    this.orderByField = orderBy;
    this.limitN = limit;
  }
  where(field, op, value) {
    return new FakeQuery(
      this.store,
      this.collPath,
      [...this.filters, { field, op, value }],
      this.orderByField,
      this.limitN,
    );
  }
  orderBy(field, dir = 'asc') {
    return new FakeQuery(
      this.store,
      this.collPath,
      this.filters,
      { field, dir },
      this.limitN,
    );
  }
  limit(n) {
    return new FakeQuery(this.store, this.collPath, this.filters, this.orderByField, n);
  }
  async get() {
    const matches = [];
    for (const [path, data] of this.store.docs.entries()) {
      if (!path.startsWith(this.collPath + '/')) continue;
      if (!this._passFilters(data)) continue;
      matches.push({ path, data });
    }
    if (this.orderByField) {
      matches.sort((a, b) => {
        const av = a.data[this.orderByField.field];
        const bv = b.data[this.orderByField.field];
        if (av < bv) return this.orderByField.dir === 'desc' ? 1 : -1;
        if (av > bv) return this.orderByField.dir === 'desc' ? -1 : 1;
        return 0;
      });
    }
    let sliced = matches;
    if (this.limitN != null) sliced = matches.slice(0, this.limitN);
    return {
      empty: sliced.length === 0,
      size: sliced.length,
      docs: sliced.map(({ path, data }) => {
        const ref = new FakeDocRef(this.store, path);
        return {
          id: ref.id,
          ref,
          exists: true,
          data: () => ({ ...data }),
        };
      }),
      forEach(cb) {
        for (const d of this.docs) cb(d);
      },
    };
  }
  _passFilters(data) {
    for (const f of this.filters) {
      const v = data[f.field];
      switch (f.op) {
        case '==':
          if (v !== f.value) return false;
          break;
        case '!=':
          if (v === f.value) return false;
          break;
        case '<':
          if (!(v < f.value)) return false;
          break;
        case '<=':
          if (!(v <= f.value)) return false;
          break;
        case '>':
          if (!(v > f.value)) return false;
          break;
        case '>=':
          if (!(v >= f.value)) return false;
          break;
        case 'in':
          if (!Array.isArray(f.value) || !f.value.includes(v)) return false;
          break;
        case 'array-contains':
          if (!Array.isArray(v) || !v.includes(f.value)) return false;
          break;
        default:
          return false;
      }
    }
    return true;
  }
}

class FakeCollection extends FakeQuery {
  constructor(store, path) {
    super(store, path);
  }
  doc(id) {
    const useId = id || `auto_${++this.store.autoId}`;
    return new FakeDocRef(this.store, `${this.collPath}/${useId}`);
  }
  async add(data) {
    const ref = this.doc();
    await ref.set(data);
    return ref;
  }
}

class FakeBatch {
  constructor(store) {
    this.store = store;
    this.ops = [];
  }
  set(ref, data) {
    this.ops.push({ type: 'set', path: ref.path, data });
  }
  update(ref, data) {
    this.ops.push({ type: 'update', path: ref.path, data });
  }
  delete(ref) {
    this.ops.push({ type: 'delete', path: ref.path });
  }
  async commit() {
    for (const op of this.ops) {
      if (op.type === 'set') this.store.docs.set(op.path, { ...op.data });
      else if (op.type === 'update') {
        const cur = this.store.docs.get(op.path);
        if (!cur) throw new Error(`batch update missing doc ${op.path}`);
        this.store.docs.set(op.path, mergeUpdate(cur, op.data));
      } else if (op.type === 'delete') this.store.docs.delete(op.path);
    }
    this.ops = [];
  }
}

class FakeTransaction {
  constructor(store) {
    this.store = store;
    this.writes = []; // defer
  }
  async get(ref) {
    if (ref instanceof FakeQuery && !(ref instanceof FakeCollection)) {
      // 允许 tx.get(query) — 但我们只支持 DocRef.get 路径作生产代码约束
      return ref.get();
    }
    return ref.get();
  }
  set(ref, data) {
    this.writes.push({ type: 'set', path: ref.path, data });
  }
  update(ref, data) {
    this.writes.push({ type: 'update', path: ref.path, data });
  }
  delete(ref) {
    this.writes.push({ type: 'delete', path: ref.path });
  }
  _flush() {
    for (const w of this.writes) {
      if (w.type === 'set') this.store.docs.set(w.path, { ...w.data });
      else if (w.type === 'update') {
        const cur = this.store.docs.get(w.path);
        if (!cur) throw new Error(`tx update missing doc ${w.path}`);
        this.store.docs.set(w.path, mergeUpdate(cur, w.data));
      } else if (w.type === 'delete') this.store.docs.delete(w.path);
    }
  }
}

class FakeFirestore {
  constructor() {
    this.docs = new Map();
    this.autoId = 0;
  }
  collection(path) {
    return new FakeCollection(this, path);
  }
  batch() {
    return new FakeBatch(this);
  }
  async runTransaction(fn) {
    const tx = new FakeTransaction(this);
    const result = await fn(tx);
    tx._flush();
    return result;
  }
  // 注入助手：直接写入数据
  _seed(path, data) {
    this.docs.set(path, { ...data });
  }
  _get(path) {
    return this.docs.get(path);
  }
  _all(coll) {
    const out = [];
    for (const [p, d] of this.docs.entries()) {
      if (p.startsWith(coll + '/')) out.push({ path: p, data: d });
    }
    return out;
  }
  _clear() {
    this.docs.clear();
    this.autoId = 0;
  }
}

// admin 模块单例 mock
const _fakeDb = new FakeFirestore();

const firestoreFn = () => _fakeDb;
firestoreFn.FieldValue = {
  increment: (n) => makeSentinelIncrement(n),
  arrayUnion: (...items) => makeSentinelArrayUnion(items),
  arrayRemove: (...items) => makeSentinelArrayRemove(items),
  serverTimestamp: () => makeSentinelServerTimestamp(),
};
firestoreFn.Timestamp = {
  now: () => ({
    _s: Math.floor(Date.now() / 1000),
    toDate: () => new Date(),
    toMillis: () => Date.now(),
  }),
  fromDate: (d) => ({
    _s: Math.floor(d.getTime() / 1000),
    toDate: () => d,
    toMillis: () => d.getTime(),
  }),
};

const adminMock = {
  initializeApp: jest.fn(),
  firestore: firestoreFn,
  messaging: () => ({
    send: jest.fn().mockResolvedValue({}),
  }),
  apps: [],
};

function makeContext(uid) {
  return { auth: uid ? { uid } : undefined };
}

/**
 * 用 firebase-functions HttpsError 的断言：检查 code 和是否 throw
 */
async function expectHttpsError(promise, code) {
  try {
    await promise;
    throw new Error(`expected HttpsError ${code} but resolved`);
  } catch (e) {
    if (!e.code || e.code !== code) {
      throw new Error(`expected code=${code} got ${e.code || 'no-code'} / ${e.message}`);
    }
  }
}

// ─────────────────────────────────────────────────────
// firebase-functions mock：onCall/onRequest 去包装，直接暴露 handler
// ─────────────────────────────────────────────────────
class FakeHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
    this.name = 'HttpsError';
  }
}

function makeFunctionsMock() {
  const identity = (fn) => fn;
  const scheduleChain = {
    onRun: identity,
    timeZone: () => ({ onRun: identity }),
  };
  const httpsObj = {
    onCall: identity,
    onRequest: identity,
    HttpsError: FakeHttpsError,
  };
  const pubsubObj = { schedule: () => scheduleChain };
  const regionChain = { https: httpsObj, pubsub: pubsubObj };
  return {
    region: () => regionChain,
    https: httpsObj,
    pubsub: pubsubObj,
    config: () => ({}),
  };
}

module.exports = {
  adminMock,
  fakeDb: _fakeDb,
  makeContext,
  expectHttpsError,
  FakeFirestore,
  makeFunctionsMock,
  FakeHttpsError,
};
