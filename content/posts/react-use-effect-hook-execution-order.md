---
title: "React 函数组件之间 useEffect hook 的执行顺序探究"
date: 2020-12-27
slug: react-use-effect-hook-execution-order
categories:
- 技术
tags:
- 前端
- React
- React Hooks
---

本文记录了在探究 React 函数组件之间 useEffect hook 的执行顺序时，所进行的实验及其结论。

具体来说，考虑如下组件树，两个 `<Test>` 组件中各有一个 effect hook，这两个副作用操作谁先，谁后？进一步地，如果这两个 effect hook 含有清除操作呢？

```jsx
function Test({ name, children = null }) {
  useEffect(() => {
    console.log(`${name} effect`);
    return () => {
      console.log(`${name} cleanup`);
    };
  });

  return children;
}

function App() {
  return (
    <Test name="parent">
      <Test name="child" />
    </Test>
  );
}
```

## effect hook 的定义

首先复习一下 React 中 effect hook 的定义。以下内容整理自 [React 文档](https://zh-hans.reactjs.org/docs/hooks-reference.html#useeffect)。

```javascript
useEffect(didUpdate);
useEffect(didUpdate, dependencies);
```

- 用途：effect hook 用于完成副作用操作。
- 参数：
  - `didUpdate` 参数接收一个包含命令式、且可能有副作用代码的函数。
  - `dependencies` 参数接收一个数组，数组中的元素表示 effect 所依赖的值。
- 执行时机：
  - 默认情况：`didUpdate` 会在每轮组件渲染完成后执行。
  - 条件执行：当传入 `dependencies` 参数时，`didUpdate` 仅在依赖值发生变化时执行
- 清除：`didUpdate` 函数可以返回一个清除函数以清除副作用操作（如取消订阅、清除定时器等）。如果组件多次渲染，则上一个 effect 会在下一个 effect 执行之前被清除。

## 探究 effect 及其清除的执行顺序

- `<Test>` 组件接收一个 name 参数以区分不同的元素
- `<Test>` 组件中使用一个 effect hook，其执行的副作用为：输出一行 `{name} effect` 的 log，清除操作为：输出一行 `{name} cleanup` 的 log。
- `mount` 这个 state 用于控制根组件的挂载与否
- `forceUpdate` 函数可以触发 react 重新渲染 `<App>` 组件
- `<App>` 组件中创建了一个三层的 `<Test>` 组件树
- 使用 `setTimeout` 延时执行 `forceUpdate()` 以及 `setMount(false)`

看代码，猜输出。你可以 [在 CodeSandbox 中运行以下代码](https://codesandbox.io/s/react-useeffect-order-test-dw7c1?file=/src/App.js) 并观察 Console 中的输出。

```jsx
function Test({ name, children = null }) {
  useEffect(() => {
    console.log(`${name} effect`);
    return () => {
      console.log(`${name} cleanup`);
    };
  });

  return children;
}

export default function App() {
  const [mount, setMount] = useState(true);
  const [, forceUpdate] = useReducer((v) => v + 1, 0);

  useEffect(() => {
    setTimeout(() => {
      console.log('\n* forceUpdate');
      forceUpdate();
    }, 1000);

    setTimeout(() => {
      console.log('\n* unmount');
      setMount(false);
    }, 2000);
  }, []);

  return mount && (
    <Test name="1">
      <Test name="1-1">
        <Test name="1-1-1" />
        <Test name="1-1-2" />
      </Test>
      <Test name="1-2">
        <Test name="1-2-1" />
        <Test name="1-2-2" />
      </Test>
    </Test>
  );
}
```

从以下输出可以看出，不同组件之间的 effect hook 的执行顺序类似于组件树的一次深度优先遍历。这表明 effect hook 的执行顺序与组件树相关。

另外，值得留意的一点是，组件重新渲染时触发的 effect 清除，与组件 unmount 时触发的 effect 清除的顺序不同。

```plaintext
1-1-1 effect 
1-1-2 effect 
1-1 effect 
1-2-1 effect 
1-2-2 effect 
1-2 effect 
1 effect 

* re-render 
1-1-1 cleanup 
1-1-2 cleanup 
1-1 cleanup 
1-2-1 cleanup 
1-2-2 cleanup 
1-2 cleanup 
1 cleanup 
1-1-1 effect 
1-1-2 effect 
1-1 effect 
1-2-1 effect 
1-2-2 effect 
1-2 effect 
1 effect 

* unmount 
1 cleanup 
1-1 cleanup 
1-1-1 cleanup
1-1-2 cleanup 
1-2 cleanup 
1-2-1 cleanup 
1-2-2 cleanup 
```

## 考虑运行时插入新的组件的情况

如果在根组件 mount 以后，向组件树中间插入一个新的组件，使得 effect 的执行顺序与组件树的遍历不同，那么 effect 清除的顺序，是组件树的遍历，还是 effect 执行顺序的逆序？观察以下代码的输出，可以发现，effect 清除的顺序，应该是组件树的遍历，而不是 effect 执行顺序的逆序。

```jsx
function DelayedMount({ children }) {
  const [mount, setMount] = useState(false);
  useEffect(() => {
    setTimeout(() => {
      console.log('\n* mount 1-append');
      setMount(true);
    }, 1000);
  }, []);

  return mount ? children : null;
}

function Test({ name, children = null }) {
  useEffect(() => {
    console.log(`${name} effect`);
    return () => {
      console.log(`${name} cleanup`);
    };
  });

  return children;
}

export default function App() {
  const [mount, setMount] = useState(true);
  const [, forceUpdate] = useReducer((v) => v + 1, 0);

  useEffect(() => {
    setTimeout(() => {
      console.log('\n* force update');
      forceUpdate();
    }, 2000);

    setTimeout(() => {
      console.log('\n* unmount all');
      setMount(false);
    }, 3000);
  }, []);

  return mount && (
    <Test name="1">
      <Test name="1-1">
        <Test name="1-1-1" />
        <Test name="1-1-2" />
      </Test>
      <DelayedMount>
          <Test name="1-append">
            <Test name="1-append-1" />
            <Test name="1-append-2" />
          </Test>
      </DelayedMount>
      <Test name="1-2">
        <Test name="1-2-1" />
        <Test name="1-2-2" />
      </Test>
    </Test>
  );
}
```

输出：
```plaintext
1-1-1 effect 
1-1-2 effect 
1-1 effect 
1-2-1 effect 
1-2-2 effect 
1-2 effect 
1 effect 

* mount 1-append 
1-append-1 effect 
1-append-2 effect 
1-append effect 

* forceUpdate 
1-1-1 cleanup 
1-1-2 cleanup 
1-1 cleanup 
1-append-1 cleanup 
1-append-2 cleanup 
1-append cleanup 
1-2-1 cleanup 
1-2-2 cleanup 
1-2 cleanup 
1 cleanup 
1-1-1 effect 
1-1-2 effect 
1-1 effect 
1-append-1 effect 
1-append-2 effect 
1-append effect 
1-2-1 effect 
1-2-2 effect 
1-2 effect 
1 effect 

* unmount all 
1 cleanup 
1-1 cleanup 
1-1-1 cleanup 
1-1-2 cleanup 
1-append cleanup 
1-append-1 cleanup 
1-append-2 cleanup 
1-2 cleanup 
1-2-1 cleanup 
1-2-2 cleanup 
```

## 结论

effect hook 在不同组件之间的执行顺序遵从如下规律：

- 组件渲染后，**执行 effect** 的顺序：组件树的**后序**深度优先遍历
- 组件**重新渲染**时，**清除 effect** 的顺序：组件树的**后序**深度优先遍历
- 组件 **unmount** 时，**清除 effect** 的顺序：组件树的**前序**深度优先遍历

本文仅通过实验的方式总结了以上规律。针对这一规律在代码实现层面的解释，可能需要参考 React Fiber 的相应实现。
