/**
 * 第二个 demo（MyApplication2）用的「待办」内存数据源。
 *
 * 为什么挂到 globalThis：Next dev 下路由模块可能被多次求值/热替换，
 * 用模块级变量会被重置；挂 globalThis 保证同一个 Node 进程里
 * GET / POST / DELETE 三个路由共享同一份数据。
 */
export interface Todo {
  id: string
  title: string
  done: boolean
  createTime: number
}

interface TodoStore {
  items: Todo[]
  seq: number
}

declare global {
  // eslint-disable-next-line no-var
  var __TODO_STORE__: TodoStore | undefined
}

function seed(): TodoStore {
  const now = Date.now()
  return {
    seq: 3,
    items: [
      { id: 't1', title: '用 HttpUtil.get 拉取待办列表', done: true, createTime: now - 30000 },
      { id: 't2', title: '用 HttpUtil.post 新增一条待办', done: false, createTime: now - 20000 },
      { id: 't3', title: '用 HttpUtil.del 删除一条待办', done: false, createTime: now - 10000 },
    ],
  }
}

function store(): TodoStore {
  if (!globalThis.__TODO_STORE__) {
    globalThis.__TODO_STORE__ = seed()
  }
  return globalThis.__TODO_STORE__
}

/** 列表（按 createTime 倒序，新增的排前面） */
export function listTodos(): Todo[] {
  return [...store().items].sort((a, b) => b.createTime - a.createTime)
}

/** 新增一条，返回新建的 Todo */
export function addTodo(title: string): Todo {
  const s = store()
  s.seq += 1
  const todo: Todo = {
    id: 't' + s.seq,
    title,
    done: false,
    createTime: Date.now(),
  }
  s.items.unshift(todo)
  return todo
}

/** 删除一条，返回被删的 Todo；不存在返回 null */
export function removeTodo(id: string): Todo | null {
  const s = store()
  const idx = s.items.findIndex((t) => t.id === id)
  if (idx === -1) return null
  const removed = s.items[idx]
  s.items.splice(idx, 1)
  return removed
}
